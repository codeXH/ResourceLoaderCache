//
//  MediaDownloader.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/4/13.
//

import UIKit

protocol MediaDownloadDelegate: AnyObject {
    func media(downloader: MediaDownloader, didReceive data: Data)
    func media(downloader: MediaDownloader, didFinished error: Error?)
    func media(downloader: MediaDownloader, didReceive response: URLResponse)
}

//: 记录视频正在下载的状态 - 清除缓存时要用到
final class MediaDownloaderStatus {

    // 将所有的请求都存储起来
    static let shared = MediaDownloaderStatus()
    
    private func `init`() {}
    
    // 正在下载的媒体集合
    private(set) var downloadingURLS = Set<URL>()
    
    // 锁
    private var mutex = PThreadMutex(type: .recursive)

    // 计算属性，返回正在下载的集合
    var urls: Set<URL> {
        return downloadingURLS
    }
    
    /// 增加一个下载
    func add(url: URL) {
        mutex.sync_same_file {
            downloadingURLS.insert(url)
        }
    }

    /// 删除一个下载
    func remove(url: URL) {
        mutex.sync_same_file {
            downloadingURLS.remove(url)
        }
    }

    /// 是否包含一个下载
    func contains(url: URL) -> Bool {
        mutex.sync_same_file {
            return downloadingURLS.contains(url)
        }
    }
}

//: 处理数据回填 + range 区分
public class MediaDownloader {
    /// 资源 URL
    private var url: URL
    /// 资源信息
    var info: ContentInfo?
    /// 缓存到磁盘
    private var cacheWorker: MediaCacheWorker?
    /// 处理网络请求
    private var actionWorker: ActionWorker?
    /// 下载媒体的代理
    weak var delegate: MediaDownloadDelegate?
    
    /// 是否下载到最后
    var downloadToEnd = false
     
    init(with url: URL, cacheWorker: MediaCacheWorker?) {
        self.url = url
        self.cacheWorker = cacheWorker
        self.info = cacheWorker?.cacheConfiguration.contentInfo
        MediaDownloaderStatus.shared.add(url: url)
    }
    
    deinit {
        MediaDownloaderStatus.shared.remove(url: url)
    }
     
    public func cancel() {
        self.actionWorker?.delegate = nil
        MediaDownloaderStatus.shared.remove(url: self.url)
        self.actionWorker?.cancel()
        self.actionWorker = nil
    }
    
    /// 具体的分片下载任务
    /// - Parameters:
    ///   - fromOffset: 开始的偏移量，首次请求 0-2 两个字节的数据
    ///   - length: 下载字节长度
    ///   - end: 是否到结尾
    public func downloadTask(fromOffset: UInt64, length: UInt64, to end: Bool) {
        guard let cacheWorker = cacheWorker else {
            delegate?.media(downloader: self, didFinished: MediaCacheError.cacheFileError)
            return
        }

        // 0-2 字节数据请求后 contentInfo?.contentLength 就会被赋值
        var rangeLength: UInt64 = 0
        if let contentLength = cacheWorker.cacheConfiguration.contentInfo?.contentLength, end == true {
            rangeLength = contentLength - fromOffset
        } else {
            rangeLength = length
        }
        
        // 根据给定的 range，获取需要请求的 range
        let actions = cacheWorker.cachedDataActions(for: fromOffset ..< (fromOffset + rangeLength))
        log("actions = \(actions)")
    
        actionWorker = ActionWorker(with: url, actions: actions, cacheWorker: cacheWorker)
        actionWorker?.delegate = self
        actionWorker?.start()
    }
    
    func downladFromStartToEnd() {
        
        guard let cacheWorker = cacheWorker else {
            delegate?.media(downloader: self, didFinished: MediaCacheError.cacheFileError)
            return
        }
        downloadToEnd = true
        let range: Range<UInt64> = 0..<2
        let actions = cacheWorker.cachedDataActions(for: range)
        actionWorker = ActionWorker(with: url, actions: actions, cacheWorker: cacheWorker)
        actionWorker?.delegate = self
        actionWorker?.start()
    }
}

// MARK: - ActionWorkerDelegate
extension MediaDownloader: ActionWorkerDelegate {
    func action(worker: ActionWorker, didReceive data: Data, isLocal: Bool) {
        delegate?.media(downloader: self, didReceive: data)
    }
    
    func action(worker: ActionWorker, didFinish error: Error?) {
        MediaDownloaderStatus.shared.remove(url: self.url)
        if error == nil && self.downloadToEnd {
            downloadToEnd.toggle()
            if let length = cacheWorker?.cacheConfiguration.contentInfo?.contentLength {
                downloadTask(fromOffset: 2, length: length, to: true)
            }
        } else {
            delegate?.media(downloader: self, didFinished: error)
        }
    }
    
    func action(worker: ActionWorker, didReceive response: URLResponse) {
        if info == nil {
            var contentType: String = ""
            var contentLength: UInt64 = 0
            var isByteRangeAccessSupported = true
            var headers: [String: Any] = [:]
            
            /// 是否支持分片下载
            if let httpResponse = response as? HTTPURLResponse {
                for key in httpResponse.allHeaderFields.keys {
                    let lowercased = (key as! String).lowercased()
                    headers[lowercased] = httpResponse.allHeaderFields[key]
                }
                isByteRangeAccessSupported = headers["accept-ranges"] as? String == "bytes"
            }
            
            /// content-range表示本次请求的数据在总媒体文件中的位置
            /// 格式是 start-end/total，因此就有content-length = end - start + 1
            /// content-length 表示数据总长度长度
            if let rangeText = headers["content-range"] as? String, let lengthText = rangeText.split(separator: "/").last {
               
                contentLength = UInt64(lengthText)!
            }
            
            /// 资源文件类型
            if let uti = UTI(mimeType: response.mimeType ?? ""), let mineType = uti.mimeType {
                contentType = mineType
            } else {
                contentType = "application/octet-stream"
            }
            
            let info = ContentInfo(contentType: contentType,
                                   byteRangeAccessSupported: isByteRangeAccessSupported,
                                   contentLength: contentLength)
            self.info = info
            
            do {
                try cacheWorker?.setContent(info: info)
            } catch {
                delegate?.media(downloader: self, didFinished: error)
            }
        }
        
        delegate?.media(downloader: self, didReceive: response)
    }
}
