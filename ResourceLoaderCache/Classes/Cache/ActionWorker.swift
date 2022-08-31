//
//  ActionWorker.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/4/14.
//

import Foundation

//: 处理完缓存，需要将数据往上层传
protocol ActionWorkerDelegate: AnyObject {
    func action(worker: ActionWorker, didReceive response: URLResponse)
    func action(worker: ActionWorker, didReceive data: Data, isLocal local: Bool)
    func action(worker: ActionWorker, didFinish error: Error?)
}

//: 用于下载的线程
struct CacheSessionManager {
    static let shared = CacheSessionManager()
    var downloadQueue: OperationQueue
    
    private init() {
        downloadQueue = OperationQueue()
        downloadQueue.name = "com.mediacache.download"
    }
}

// 通知的 key
public let CacheConfigurationKey = "CacheConfigurationKey"
public let CacheFinishedErrorKey = "CacheFinishedErrorKey"

//: 下载数据
class ActionWorker {
    
    /// 记录数据的偏移量
    private var startOffset = 0
    /// 记录通知触发的时间
    private var notifyTime: TimeInterval = 0.1
   
    /// 媒体 URL
    private var url: URL
    /// 缓存的类型和范围 - 集合
    private var actions: [CacheAction] = []
    /// 缓存 Worker
    private var cacheWorker: MediaCacheWorker
    
    /// 是否可以保存到缓存
    var canSaveToCache = true
    /// 是否取消操作
    private var isCancelled = false
    /// 处理代理方法
    weak var delegate: ActionWorkerDelegate?

    /// 下载任务
    var task: URLSessionDataTask?
    /// 下载的缓冲区
    lazy var sessionDelegateObject = URLSessionDelegateObject(delegate: self)
    /// 用于下载
    lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: self.sessionDelegateObject, delegateQueue: CacheSessionManager.shared.downloadQueue)
    }()
    
    init(with url: URL, actions: [CacheAction],  cacheWorker: MediaCacheWorker) {
        self.url = url
        self.actions = actions
        self.cacheWorker = cacheWorker
    }
    
    deinit {
        cancel()
    }
    
    // MARK: - Actions
    /// 开始分片下载
    func start() {
        processActions()
    }
    
    /// 取消下载
    func cancel() {
        isCancelled = true
    }
    
    /// 执行不同的 action - 递归调用会导致栈空间不足
    private func processActions() {
        
        if isCancelled { return }
        
        guard let action = actions.first else {
            log("delegate?.action(worker: self, didFinish: nil)")
            delegate?.action(worker: self, didFinish: nil)
            return
        }
        
        actions.removeFirst()
        
        switch action.type {
        case .local:
            cache(at: action)
        case .remote:
            request(at: action)
        }
    }
    
    /// 加载本地缓存
    /// - Parameter action: 缓存数据
    func cache(at action: CacheAction) {
        // 如果本地缓存数据中有该数据，则直接将数据抛出
        
        guard let data = cacheWorker.cached(for: action.range) else {
            delegate?.action(worker: self, didFinish: MediaCacheError.noFoundLocalCacheData)
            return
        }
        
        if action.range.lowerBound == 0, action.range.upperBound == 2 {
            log("cache delegate?.action(worker: self, didReceive: URLResponse())")
            delegate?.action(worker: self, didReceive: URLResponse())
        }
        log("cache delegate?.action(worker: self, didReceive: data, isLocal: true)")
        delegate?.action(worker: self, didReceive: data, isLocal: true)
        processActions()
    }
    
    /// 开始分片请求 - 设置分片的范围
    /// - Parameter action: 分片数据
    func request(at action: CacheAction) {
        let fromOffset = action.range.lowerBound
        let endOffset = Int(action.range.lowerBound) + action.range.count - 1
        var request = URLRequest(url: url)
        request.setValue("bytes=\(fromOffset)-\(endOffset)", forHTTPHeaderField: "Range")
        log("下载数据范围 bytes =\(fromOffset)-\(endOffset)")
        startOffset = Int(action.range.lowerBound)
        task = session.dataTask(with: request)
        task?.resume()
    }
    
    /// 下载进度
    /// - Parameters:
    ///   - flush: 下载是否完整
    ///   - finished: 是否完成下载
    func notifyDownloadProgress(with flush: Bool, finished: Bool) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let interval = 0.1
        // 防止同一时间通知多次
        if (notifyTime < currentTime - interval) || flush {
            notifyTime = currentTime
            let configuration = cacheWorker.cacheConfiguration
            NotificationCenter.default.post(name: .CacheManagerDidUpdateCache,
                                            object: self,
                                            userInfo: [CacheConfigurationKey: configuration])
            // 如果下载完成，调用 finished 方法
            if finished, configuration.progress >= 1.0 {
                notifyDownloadFinished(with: nil)
            }
        }
    }
    
    /// 下载完成的通知
    func notifyDownloadFinished(with error: Error?) {
        let configuration = cacheWorker.cacheConfiguration
        let info: [String: Any] = [CacheConfigurationKey: configuration, CacheFinishedErrorKey: error as Any]
        NotificationCenter.default.post(name: .CacheManagerDidFinishCache,
                                        object: self,
                                        userInfo: info)
    }
}

// MARK: - URLSessionDelegateObjectDelegate
extension ActionWorker: URLSessionDelegateObjectDelegate {
    /// URLSession 的代理方法给了 sessionDelegateObject， 在 sessionDelegateObject 中处理过 10kb 缓冲后回调
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // 只下载音视频
        if let mimeType = response.mimeType, !mimeType.contains("video/"), !mimeType.contains("audio/"), !mimeType.contains("application") {
            completionHandler(.cancel)
        } else {
            log("request delegate?.action(worker: self, didReceive: response)")
            delegate?.action(worker: self, didReceive: response)
            
            if canSaveToCache {
                cacheWorker.startWritting()
            }
            completionHandler(.allow)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    
        if isCancelled { return }
        var ran: Range<UInt64> = 0..<1
        if canSaveToCache {
            let range = UInt64(startOffset) ..< UInt64(startOffset + data.count)
            ran = range
            do {
                try cacheWorker.cache(data: data, for: range)
            } catch {
                delegate?.action(worker: self, didFinish: error)
                return
            }
            cacheWorker.save()
        }
        startOffset += data.count
        log("request delegate?.action(worker: self, didReceive: data, isLocal: false, range: \(ran)")
        delegate?.action(worker: self, didReceive: data, isLocal: false)
        notifyDownloadProgress(with: false, finished: false)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        log("urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)")
        if canSaveToCache {
            cacheWorker.finishWritting()
            cacheWorker.save()
        }
        if let error = error {
            delegate?.action(worker: self, didFinish: error)
            notifyDownloadFinished(with: error)
        } else {
            notifyDownloadProgress(with: true, finished: true)
            processActions()
        }
    }
}
