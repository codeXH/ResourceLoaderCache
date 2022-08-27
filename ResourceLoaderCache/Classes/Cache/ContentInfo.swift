//
//  ContentInfo.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/4/12.
//

import UIKit

//: 视频的整体内容信息
struct ContentInfo: Codable, CustomDebugStringConvertible {

    var contentType: String
    var byteRangeAccessSupported: Bool
    var contentLength: UInt64

    var debugDescription: String {
        let cls = String(describing: Self.self)
        let length = "contentLength:\(contentLength)"
        let type = "contentType:\(contentType)"
        let support = "byteRangeAccessSupported:\(byteRangeAccessSupported)"
        return "\(cls)\n\(length)\n\(type)\n\(support)"
    }
}
