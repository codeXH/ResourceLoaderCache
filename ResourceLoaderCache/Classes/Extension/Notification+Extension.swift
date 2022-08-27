//
//  Notification+Extension.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/6/20.
//

import Foundation

public extension Notification.Name {
    
    // 更新缓存
    static var CacheManagerDidUpdateCache = Notification.Name("CacheManagerDidUpdateCache")
    // 缓存保存完成
    static var CacheManagerDidFinishCache = Notification.Name("CacheManagerDidFinishCache")
    // 清理缓存
    static var CacheManagerDidCleanCache = Notification.Name("CacheManagerDidCleanCache")
}
