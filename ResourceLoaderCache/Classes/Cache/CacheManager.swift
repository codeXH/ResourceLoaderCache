//
//  CacheManager.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/4/18.
//

import Foundation
import UIKit

//: 管理缓存 - 缓存文件的创建、删除、计算缓存大小
//  让 url = NSString（字符串：“http://xxx/test.swift”）
//  print(url.lastPathComponent) test.swift
//  print(url.pathExtension) swift
public struct CacheManager {

    static let shared = CacheManager()
    
    private func `init`() {}

    /// 缓存路径 /tmp/mediaCache
    private let cachePath = FileManager().temporaryPath(with: "mediaCache")

    // MARK: - 缓存文件路径
    
    /// 生成缓存文件路径- /tmp/mediaCache/xxx.mov
    func cachedFilePath(for url: URL) -> URL {
        let path = url.absoluteString.md5
        let pathComponent = path.urlPath().appendingPathExtension(url.pathExtension)
        return cachePath.appendingPathComponent(pathComponent.stringPath())
    }
    
    /// 生成归档文件路径  /tmp/mediaCache/xxx.mov.json
    func configurationFilePath(for url: URL) -> URL {
        let filePath = cachedFilePath(for: url)
        return filePath.appendingPathExtension("cache_range")
    }


    // MARK: - 计算所有缓存文件大小
    /// 计算 /tmp/mediaCache 文件夹下缓存大小
    public func calcuteCacheSize(completion: @escaping (_ size: UInt) -> Void) {
        FileManager().cacheSize(at: cachePath, completion: completion)
    }

    // MARK: - 清除所有缓存文件（不包含正在下载的文件）
    /// 清理临时文件 - 不包括正在下载的文件
    /// - Parameter completion: 返回清理结果
    public func clearCache(completion: @escaping (_ success: Bool) -> Void) {

        var downloadingFiles: Set<URL> = []
        MediaDownloaderStatus.shared.urls.forEach { url in
            let file = cachedFilePath(for: url)
            downloadingFiles.insert(file)
            let configurationPath = configurationFilePath(for: url)
            downloadingFiles.insert(configurationPath)
        }
            
        do {
            let paths = try FileManager.default.contentsOfDirectory(atPath: cachePath.stringPath())
            for path in paths {
                let filePath = cachePath.appendingPathComponent(path)
                if downloadingFiles.contains(filePath) {
                    continue
                } else {
                    try FileManager.default.removeItem(atPath: filePath.stringPath())
                    completion(true)
                }
                
            }
        } catch {
            log(error.localizedDescription)
            completion(false)
        }
    }

    // MARK: - 清除指定缓存文件（不包含正在下载的文件）
    /// 清理指定路径的缓存文件
    /// - Parameters:
    ///   - url: 文件路径
    ///   - completion: 结果
    public func cleanCache(for url: URL, completion: @escaping (_ success: Bool) -> Void) {
        // 如果 downloads 中包含直接返回 false
        if MediaDownloaderStatus.shared.urls.contains(url) {
            completion(false)
            return
        }
        
        // 清除文件缓存
        let path = cachedFilePath(for: url)
        if path.isFileExists {
            do {
                try FileManager.default.removeItem(at: path)
                completion(true)
            } catch {
                log(error.localizedDescription)
                completion(false)
            }
        }
        
        // 清除归档文件缓存
        let filePath = configurationFilePath(for: url)
        if filePath.isFileExists {
            do {
                try FileManager.default.removeItem(at: filePath)
                completion(true)
            } catch {
                log(error.localizedDescription)
                completion(false)
            }
        }
    }
}
