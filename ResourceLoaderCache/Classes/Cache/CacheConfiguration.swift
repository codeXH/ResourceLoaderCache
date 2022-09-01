//
//  CacheConfiguration.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/4/14.
//
//  swift 如果要使用 NSCopying, 可以用 struct 代替
//  struct 是不能遵循 NSCoding 协议的
//  用 Codable 代替 NSCoding 协议
//  因为 NSValue 是对 C 和 Objective-C 数据的封装（项目中即NSRange), 而 Range 遵循了 Codable 协议，所以直接使用即可
//

import Foundation

//: 下载内容的字节和时间
struct DownloadInfo: Codable {
    var bytes: Int?
    var time: TimeInterval?
}

//: 缓存配置 - 数据 range 的归档解档
//: 归档的文件名和存储数据的文件名不是同一个：需要给归档的文件添加后缀
//: 可对外提供下载速度和进度
public class CacheConfiguration: Codable {

    var url: URL?
    private(set) var filePath: String?
    private(set) var fileName: String? // cache_range
    
    var contentInfo: ContentInfo? // 视频信息
    private(set) var downloadInfos: [DownloadInfo] = []  // 用于计算下载速度
    private var internalCacheFragments: [Range<UInt64>] = []

    // MARK: - 计算属性
    /// 下载进度
    public var progress: Float {
        guard let length = contentInfo?.contentLength, length > 0 else { return 0 }
        return Float(downloadedBytes ?? 0) / Float(length)
    }

    /// 下载字节数
    public var downloadedBytes: Int? {
        return internalCacheFragments.reduce(into: 0) { $0 += $1.count }
    }

    /// 下载速度
    public var downloadSpeed: Double? {
        var info: (Int, TimeInterval) = (0, 0)
        info = downloadInfos.reduce(into: (0, 0)) { result, downloadInfo in
            result.0 += downloadInfo.bytes ?? 0
            result.1 += downloadInfo.time ?? 0
        }
        return Double(info.0) / Double(1024) / info.1
    }
    
    /// 缓存碎片
    var cacheFragments: [Range<UInt64>] {
        return internalCacheFragments
    }

    // MARK: - init
    /// 将文件解码为  CacheConfiguration
    /// - Parameter filePath: 归档文件路径
    static func configuration(with filePath: String) -> CacheConfiguration {
    
        guard let data = FileManager.default.contents(atPath: filePath),
                let configuration = try? JSONDecoder().decode(self, from: data) else {
            let con = CacheConfiguration()
            con.fileName = filePath.urlPath().lastPathComponent
            con.filePath = filePath
            return con
        }
        configuration.filePath = filePath
        return configuration
    }

    // MARK: - update
    /// 延时存储
    func save() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.archiveData()
        }
    }

    /// 将数据写入到文件中
    private func archiveData() {
        do {
            if let data = try? JSONEncoder().encode(self) {
                try data.write(to: URL(fileURLWithPath: filePath ?? ""), options: .atomic)
            }
        } catch {
            log(error.localizedDescription)
        }
    }

    /// 添加 range 到 CacheFragments 中 - seek 时将连续的 range 进行合并
    /// 0..<2, 2..<100 合并为 0..<100
    /// - Parameter range: 分片数据的 range
    func addCacheFragment(range: Range<UInt64>) {
        guard !range.isEmpty else { return }
        
        if internalCacheFragments.isEmpty {
            internalCacheFragments.append(range)
        } else {
            // 保存大数时 indexSet 不存储每一个数，只存储 0..<x 范围，性能比 Set 更好
            var indexSet = IndexSet()
            for (index, ran) in internalCacheFragments.enumerated() {
                // range 包含在数组中
                if range.upperBound <= ran.lowerBound {
                    
                    if indexSet.isEmpty {
                        indexSet.insert(index)
                        break
                    }
                } else if range.lowerBound <= ran.upperBound, range.upperBound > ran.lowerBound {
                    // range 的一部分包含在数组中
                    indexSet.insert(index)
                } else if range.lowerBound >= ran.upperBound {
                    // range 不包含在数组中
                    if index == internalCacheFragments.count - 1 {
                        indexSet.insert(index)
                    }
                }
            }
            
            // range 和数组中两个 range 都相交
            if indexSet.count > 1 {
                let firstRange = internalCacheFragments[indexSet.first!]
                let lastRange = internalCacheFragments[indexSet.last!]
                let location = min(firstRange.lowerBound, range.lowerBound)
                let endOffset = max(lastRange.upperBound, range.upperBound)
                let combineRange = location ..< endOffset
                internalCacheFragments.remove(at: indexSet)
                internalCacheFragments.insert(combineRange, at: 0)
            } else if indexSet.count == 1 {
                // range 完全包含于数组的一个 range 或 range 完全不相交与数组中任何一个值
                let firstRange = internalCacheFragments[indexSet.first!]
                let expandFirstRange = firstRange.lowerBound ..< firstRange.upperBound + 1
                let expandFragmentRange = range.lowerBound ..< range.upperBound + 1
                let intersectionRange = expandFirstRange.clamped(to: expandFragmentRange)
                
                if intersectionRange.isEmpty {
                    if firstRange.lowerBound > range.lowerBound {
                        // range 的起点更小
                        internalCacheFragments.insert(range, at: indexSet.last!)
                    } else {
                        // range 完全不相交与数组
                        internalCacheFragments.insert(range, at: indexSet.last! + 1)
                    }
                } else {
                    // 完全包含于数组
                    let location = min(firstRange.lowerBound, range.lowerBound)
                    let endOffset = max(firstRange.upperBound, range.upperBound)
                    let combineRange = location ..< endOffset
                    internalCacheFragments.remove(at: indexSet.first!)
                    // TODO: indexSet(3..<4) 可能会超出 internalCacheFragments 的下标
                    internalCacheFragments.insert(combineRange, at: indexSet.first!)
                }
            }
        }
    }
    
    /// 记录保存分段视频的数据和花费的时间
    func addDownloadedBytes(bytes: Int, spent time: TimeInterval) {
        downloadInfos.append(DownloadInfo(bytes: bytes, time: time))
    }
}
