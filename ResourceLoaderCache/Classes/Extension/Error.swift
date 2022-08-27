//
//  Error.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/6/17.
//

import Foundation

/// 扩展一个error类型
enum MediaCacheError: Error {
    case noData
    case cacheFileError
    case noFoundLocalCacheData
    case resourceLoaderCancelled
}

extension MediaCacheError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noData:
            return "没有数据"
        case .cacheFileError:
            return "初始化缓存文件错误"
        case .noFoundLocalCacheData:
            return "获取本地缓存数据失败"
        case .resourceLoaderCancelled:
            return "Resource loader cancelled"
        }
    }
}
