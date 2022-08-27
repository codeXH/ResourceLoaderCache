//
//  URLSessionDelegateObject.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/4/14.
//

import Foundation

//: URLSessionDelegate 加了一层，数据需要接着往上抛
protocol URLSessionDelegateObjectDelegate: AnyObject {
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data)

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?)
}

//: URLSession 是继承自 NSObject，代理方法都继承自 NSObjectProtocol，所以这里要继承自 NSObject
//: 给 URLSessionDelegate 加了一层，创建了一个 10Kb 的缓冲区
class URLSessionDelegateObject: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {
    
    /// 记录缓冲数据
    private var bufferData = Data()
    /// 缓冲数据大小 10 kb
    private let bufferSize = 10 * 1024
    /// 将下载方法代理出去
    var delegate: URLSessionDelegateObjectDelegate
    /// 用于为缓冲区写数据时加锁
    private var mutex = PThreadMutex(type: .recursive)

    init(delegate: URLSessionDelegateObjectDelegate) {
        self.delegate = delegate
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        delegate.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        mutex.sync_same_file {
            bufferData.append(data)
            // 缓冲区内容大于 10k 后，清空缓冲区域，抛出数据
            if bufferData.count > bufferSize {
                let range = 0..<bufferData.count
                let data = bufferData[range]
                bufferData.replaceSubrange(range, with: [])
                delegate.urlSession(session, dataTask: dataTask, didReceive: data)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        mutex.sync_same_file {
            // 请求完成后，清空缓冲区，将数据抛出去
            if !bufferData.isEmpty && error == nil {
                let range = 0 ..< bufferData.count
                let data = bufferData[range]
                bufferData.replaceSubrange(range, with: [])
                delegate.urlSession(session, dataTask: task as! URLSessionDataTask, didReceive: data)
            }
        }
        delegate.urlSession(session, task: task, didCompleteWithError: error)
    }
}
