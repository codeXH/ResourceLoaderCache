//
//  ResourceLoader.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/4/25.
//

import Foundation
import AVFoundation

//: 资源加载器
//: 一个 url 可以对应多个 AVAssetResourceLoadingRequest
final class ResourceLoader {
    
    private(set) var url: URL
    private var mediaDownloader: MediaDownloader
    
    var resourceLoadError: ((ResourceLoader, Error) ->Void)?
    private var pendingRequestWorks: [ResourceLoadingRequestWorker] = []
    
    init(with url: URL) {
        self.url = url
        self.mediaDownloader = MediaDownloader(with: url, cacheWorker: MediaCacheWorker(with: url))
    }
    
    /// 处理拦截到的 AVAssetResourceLoadingRequest，根据媒体支持的类型不同，request 可能会有多个
    /// - Parameter request: 资源请求对象
    func add(request: AVAssetResourceLoadingRequest) {
        MediaDownloaderStatus.shared.add(url: url)
        
        let requestWorker = ResourceLoadingRequestWorker(request: request, mediaDownloader: mediaDownloader)
        
        pendingRequestWorks.append(requestWorker)
        requestWorker.resourceLoadingError = { [weak self] (loading, error) in
            self?.requestWorker(with: loading, error: error)
        }
        requestWorker.startWork()
    }
    
    /// ResourceLoadingRequestWorker 下载结果回调
    func requestWorker(with loading: ResourceLoadingRequestWorker, error: Error?) {
        remove(request: loading.request)
        
        if error != nil {
            resourceLoadError?(self, error!)
        }
        
        if pendingRequestWorks.isEmpty {
            MediaDownloaderStatus.shared.remove(url: url)
        }
    }
    
    /// 移除资源请求对象
    func remove(request: AVAssetResourceLoadingRequest) {
        for work in pendingRequestWorks where work.request == request {
            work.finish()
            pendingRequestWorks.removeAll { $0 == work}
        }
    }
    
    /// 取消资源请求
    func cancel() {
        mediaDownloader.cancel()
        pendingRequestWorks.removeAll()
        MediaDownloaderStatus.shared.remove(url: url)
    }
}
