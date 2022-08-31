//
//  ResourceLoadingRequestWorker.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/6/20.
//

import Foundation
import AVFoundation
import UIKit

//: 资源请求完成后需要将数据回填到 AVAssetResouceLoadingRequest
final class ResourceLoadingRequestWorker {
    
    let request: AVAssetResourceLoadingRequest
    private let mediaDownloader: MediaDownloader
    
    var resourceLoadingError: ((ResourceLoadingRequestWorker, Error?) -> Void)?
    
    init(request: AVAssetResourceLoadingRequest, mediaDownloader: MediaDownloader) {
        self.request = request
        self.mediaDownloader = mediaDownloader
        self.mediaDownloader.delegate = self
    }
    
    /// 判断需要下载的数据范围
    /// 首次请求数据是 0..<2 
    func startWork() {
        
        guard let dataRequest = request.dataRequest else { return }
        
        var offset = dataRequest.requestedOffset
        let length = dataRequest.requestedLength
        let toEnd = dataRequest.requestsAllDataToEndOfResource
        
        // 如果数据回填过，则 currentOffset 会发生变化
        if dataRequest.currentOffset != 0 {
            offset = dataRequest.currentOffset
        }
        log("offset = \(offset) length = \(length) toEnd = \(toEnd)")
        mediaDownloader.downloadTask(fromOffset: UInt64(offset), length: UInt64(length), to: toEnd)
    }
    
    /// 数据响应 - 根据 0-2 字节数据填充数据类型信息
    func fullfillContentInfo() {
        let contentInformationRequest = request.contentInformationRequest
        if mediaDownloader.info != nil, contentInformationRequest?.contentType == nil {
            contentInformationRequest?.contentType = mediaDownloader.info?.contentType
            contentInformationRequest?.contentLength = Int64(mediaDownloader.info!.contentLength)
            contentInformationRequest?.isByteRangeAccessSupported = mediaDownloader.info!.byteRangeAccessSupported
        }
    }
    
    /// 如果数据已经请求完成 需要 finish
    func finish() {
        if request.isFinished == false {
           request.finishLoading(with: MediaCacheError.resourceLoaderCancelled)
       }
    }
}

// MARK: - MediaDownloadDelegate
extension ResourceLoadingRequestWorker: MediaDownloadDelegate {
    
    // 数据响应
    func media(downloader: MediaDownloader, didReceive response: URLResponse) {
        fullfillContentInfo()
    }
    
    // 数据回填
    func media(downloader: MediaDownloader, didReceive data: Data) {
        request.dataRequest?.respond(with: data)
    }
    
    // 完成一个ResourceLoader
    func media(downloader: MediaDownloader, didFinished error: Error?) {
        
        if let err = error as? URLError, err.code == URLError.Code.cancelled { return }
        (error == nil) ? request.finishLoading() : request.finishLoading(with: error!)
        
        // 把错误回调给 ResourceLoader
        resourceLoadingError?(self, error)
    }
}

// MARK: - Equatable
extension ResourceLoadingRequestWorker: Equatable {
    static func == (lhs: ResourceLoadingRequestWorker, rhs: ResourceLoadingRequestWorker) -> Bool {
        return lhs.request == rhs.request
    }
}
