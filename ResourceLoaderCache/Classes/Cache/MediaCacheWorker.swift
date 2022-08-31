//
//  MediaCacheWorker.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/4/14.
//

import Foundation
import UIKit

let PackageLength = 204800 // 200kb per package

//: 缓存写入到本地文件中, 13.0 以后 大部分方法都得替换
//: 创建缓存文件
class MediaCacheWorker {

    private var readFileHandle: FileHandle
    private var writeFileHandle: FileHandle
    private var internalCacheConfiguraion: CacheConfiguration
    /// 提供接口
    var cacheConfiguration: CacheConfiguration {
        return internalCacheConfiguraion
    }

    private var startWriteDate = Date()
    private var writeBytes: Int = 0
    private(set) var writting = false

    // MARK: - init
    init?(with url: URL) {

        // 缓存文件路径
        let path = CacheManager.shared.cachedFilePath(for: url)
        // 归档文件路径
        let configurePath = CacheManager.shared.configurationFilePath(for: url)
        
        // 创建 mediaCache 文件夹
        FileManager().createDirectory(path.deletingLastPathComponent())
        // 创建 xxx.mp4 文件
        FileManager().createFile(path.stringPath())
        // 创建 xxx.mp4.cache_configue 文件
        FileManager().createFile(configurePath.stringPath())
        
        do {
            self.readFileHandle = try FileHandle(forReadingFrom: path)
            self.writeFileHandle = try FileHandle(forWritingTo: path)
            self.internalCacheConfiguraion = CacheConfiguration.configuration(with: configurePath.stringPath())
            self.internalCacheConfiguraion.url = url
        } catch {
            log(error.localizedDescription)
            return nil
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        save()
        writeFileHandle.closeFile()
        readFileHandle.closeFile()
    }

    // MARK: - FileHandle 操作

    /// 将缓存数据写入到文件中
    /// - Parameters:
    ///   - data: 要写入的数据
    ///   - range: 写入的范围
    func cache(data: Data, for range: Range<UInt64>) throws {
        // 先移动文件指针到指定位置
        if #available(iOS 13.0, *) {
            try writeFileHandle.seek(toOffset: range.lowerBound)
        } else {
            writeFileHandle.seek(toFileOffset: range.lowerBound)
        }
        
        // 将数据写入缓存文件
        writeFileHandle.write(data)
        writeBytes += data.count
        
        // 将数据写入到归档文件
        internalCacheConfiguraion.addCacheFragment(range: range)
    }

    /// 读取指定范围内的 data
    /// - Parameter range: 指定要读取的范围
    /// - Returns: 返回 Data
    func cached(for range: Range<UInt64>) -> Data? {
        do {
            // 先移动文件指针到指定位置
            if #available(iOS 13.0, *) {
                try readFileHandle.seek(toOffset: range.lowerBound)
            } else {
                readFileHandle.seek(toFileOffset: range.lowerBound)
            }
            // 读取数据
            return readFileHandle.readData(ofLength: range.count)
        } catch {
            log(error.localizedDescription)
            return nil
        }
    }
    
    /// 根据 range 分割任务 - 如果没有交集则为 remote，如果有交集， 则交集为 local，不相交部分为 remote
    /// - Parameter range: 需要下载的范围
    /// - Returns: 区分是否有缓存
    func cachedDataActions(for range: Range<UInt64>) -> [CacheAction] {

        guard !range.isEmpty else { return [] }

        let cachedFragments = internalCacheConfiguraion.cacheFragments
        var actions: [CacheAction] = []

        for fragmentRange in cachedFragments {
            
            // 没有交集
            if fragmentRange.lowerBound >= range.upperBound { continue }
            
            // range 和已经存储的 碎片是否有交集
            let intersectionRange = range.clamped(to: fragmentRange)
            if !intersectionRange.isEmpty {
                // action 最大数据量为 200kb
                let package = intersectionRange.count / PackageLength
                for i in 0...package {

                    let offset = i * PackageLength
                    let offsetLocation = intersectionRange.lowerBound + UInt64(offset)
                    let maxLocation = intersectionRange.upperBound
                    let length = (offsetLocation + UInt64(PackageLength)) > maxLocation ? (maxLocation - offsetLocation) : UInt64(PackageLength)
                    // 如果有交集 - 则分配 .local
                    let action = CacheAction(type: .local, range: UInt64(offsetLocation)..<UInt64(length + offsetLocation))
                    actions.append(action)
                }
            }
        }

        if actions.isEmpty {
            // 没有交集，存储为 .remote
            let action = CacheAction(type: .remote, range: range)
            actions.append(action)
        } else {
            var localRemoteActions = [CacheAction]()
            for (index, obj) in actions.enumerated() {
                let actionRange = obj.range
                if index == 0 {
                    if range.lowerBound < actionRange.lowerBound {
                        let ran = range.lowerBound..<actionRange.lowerBound
                        let action = CacheAction(type: .remote, range: ran)
                        localRemoteActions.append(action)
                    }
                    localRemoteActions.append(obj)
                } else {
                    let lastAction = localRemoteActions.last!
                    let lastOffset = lastAction.range.lowerBound + UInt64(lastAction.range.count)
                    if actionRange.lowerBound > lastOffset {
                        let ran = lastOffset..<actionRange.lowerBound
                        let action = CacheAction(type: .remote, range: ran)
                        localRemoteActions.append(action)
                    }
                    localRemoteActions.append(obj)
                }
                
                if (index == actions.count - 1) {
                    let localEndOffset = actionRange.upperBound
                    if range.upperBound > localEndOffset {
                        let action = CacheAction(type: .remote, range: localEndOffset..<range.upperBound)
                        localRemoteActions.append(action)
                    }
                }
            }
            actions = localRemoteActions
        }

        return actions
    }

    /// 根据 contentInfo 的长度设置 writeFileHandle 截断的数据，如果 writeFileHandle 方式抛错，该方法也应该失败
    /// - Parameter info: ContenInfo
    func setContent(info: ContentInfo) throws {
        
        if #available(iOS 13.0, *) {
            try writeFileHandle.truncate(atOffset: info.contentLength)
            try writeFileHandle.synchronize()
        } else {
            writeFileHandle.truncateFile(atOffset: info.contentLength)
        }

        writeFileHandle.synchronizeFile()
        internalCacheConfiguraion.contentInfo = info
    }

    /// 数据保存 - 如果应用退到后台，会触发保存操作
   @objc func save() {
        writeFileHandle.synchronizeFile()
        internalCacheConfiguraion.save()
    }

    /// 开始写入数据
    func startWritting() {
        if writting == false {
            // 退到后台，触发保存操作
            NotificationCenter.default.addObserver(self, selector: #selector(save), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        }
        writting.toggle()
        startWriteDate = Date()
        writeBytes = 0
    }

    /// 完成数据写入
    func finishWritting() {
        if writting == true {
            writting.toggle()
            let time = Date().timeIntervalSince(startWriteDate)
            internalCacheConfiguraion.addDownloadedBytes(bytes: writeBytes, spent: time)
        }
    }
}
