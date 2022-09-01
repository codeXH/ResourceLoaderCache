//
//  ResourceLoaderManager.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/6/20.
//

import Foundation
import AVFoundation

/// 回调到应用层，需要显式调用
protocol ResourceLoaderManagerDelegate: AnyObject {
    func resourceLoaderManagerLoad(url: URL, didFail error: Error?)
}

//: 将系统播放 - 代理到边下边播代理
//: AVAssetResourceLoader 仅在 AVURLAsset 不知道如何去加载这个 URL 资源时才会被调用
//: AVURLAsset 的时候需要把目标视频URL地址的scheme替换为系统不能识别的scheme
final public class ResourceLoaderManager: NSObject, AVAssetResourceLoaderDelegate {
    /// 原始 URL
    private var originURL: URL!
    /// ResourceLoader 在 finish 之前需要强引用，避免其释放
    private var loaders: [String: ResourceLoader] = [:]
    ///
    weak var delegate: ResourceLoaderManagerDelegate?
    
    /// 设置边下边播代理
    public func playerItem(with url: URL) -> AVPlayerItem? {
        self.originURL = url
        guard let assetURL = url.replaceScheme() else { return nil}
        
        let urlAsset = AVURLAsset(url: assetURL, options: nil)
        urlAsset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        
        let playerItem = AVPlayerItem(asset: urlAsset)
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        return playerItem
    }
    
    /// 清除缓存
    public func cleanCache() {
        loaders.removeAll()
        CacheManager.shared.clearCache { success in
            log("success = \(success)")
        }
    }
    
    /// 取消加载
    public func cancleLoaders() {
        loaders.keys.forEach {
            loaders[$0]?.cancel()
        }
        loaders.removeAll()
    }
    
    /// 根据 URL 生成 Key
    func keyForResourceLoader(requestURL: URL?) -> String? {
        return requestURL?.absoluteString
    }
    
    ///  根据 Key 查找 ResourceLoader
    func loader(for request: AVAssetResourceLoadingRequest) -> ResourceLoader? {
        return loaders[keyForResourceLoader(requestURL: request.request.url) ?? ""]
    }
    
    // MARK: - AVAssetResourceLoaderDelegate
    
    /// 是否加载请求的资源 -保存 loadingRequest 并开启下载数据的任务，下载回调中拿到响应数据后再对 loadingRequest 进行填充。
    /// - Parameters:
    ///   - resourceLoader: 资源加载器
    ///   - loadingRequest: 资源请求对象 - you must retain the instance of AVAssetResourceLoadingRequest until after loading is finished.
    /// - Returns: 是否加载
    /// 需要将修改过 scheme 的 URL 换回正常 URL
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        // 同一个loadingRequest 会触发多次 - 0-2/0-8136036/409600-8136036
        if let dataRequest = loadingRequest.dataRequest {
            log("loadingRequest offset = \(dataRequest.currentOffset) length = \(dataRequest.requestedLength)")
        }
        
        guard let resourceURL = loadingRequest.request.url else {
            return false
        }
        
        if let loader = loader(for: loadingRequest) {
            log("old loadingRequest start")
            loader.add(request: loadingRequest)
        } else {
            // ResourceLoader 使用原始 URL 初始化
            let loader = ResourceLoader(with: originURL)
            // 错误处理
            loader.resourceLoadError = { [weak self] (loader, error) in
                loader.cancel()
                log("loadingRequest error \(error)")
                self?.delegate?.resourceLoaderManagerLoad(url: loader.url, didFail: error)
            }
            // 保存 loader
            if let key = keyForResourceLoader(requestURL: resourceURL) {
                loaders[key] = loader
            }
            log("new loadingRequest start")
            loader.add(request: loadingRequest)
        }
        
        return true
    }
    
    /// 把 loadingRequest 移出下载任务的回调列表（停止填充）
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        let loader = loader(for: loadingRequest)
        loader?.remove(request: loadingRequest)
    }
}
