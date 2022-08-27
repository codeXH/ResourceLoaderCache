//
//  FileManager+CJAdd.swift
//  CJCore
//
//  Created by 陈煜 on 2021/3/1.
//  沙盒路劲
//  Documents 目录：您应该将所有的应用程序数据文件写入到这个目录下。这个目录用于存储用户数据。该路径可通过配置实现iTunes共享文件。可被iTunes备份。
//  Library 目录：这个目录下有两个子目录：
//  Preferences 目录：包含应用程序的偏好设置文件。您不应该直接创建偏好设置文件，而是应该使用NSUserDefaults类来取得和设置应用程序的偏好.
//  Caches 目录：用于存放比临时文件更久的缓存文件
//  tmp 目录：这个目录用于存放临时文件，保存应用程序再次启动过程中不需要的信息。

import Foundation

// MARK: - 文件路劲协议
/// 文件路径协议
public protocol FilePathProtocol {
    /// 路径URL
    func urlPath() -> URL
    /// 路径字符串
    func stringPath() -> String
}

/// 文件路径协议拓展
public extension FilePathProtocol {
    /// 文件是否已经存在
    var isFileExists: Bool {
        let isExists = FileManager.default.fileExists(atPath: stringPath())
        return isExists
    }

    /// 是否是目录
    var isDirectory: Bool {
        var isDirectory: ObjCBool = false
        let isExists = FileManager.default.fileExists(atPath: stringPath(), isDirectory: &isDirectory)
        return isExists && isDirectory.boolValue
    }
}

/// 字符串实现FilePathProtocol协议
extension String: FilePathProtocol {
    /// 获取路径字符串
    public func stringPath() -> String {
        return self
    }
    /// 获取路径URL
    public func urlPath() -> URL {
        return URL(fileURLWithPath: self)
    }
}

/// URL实现FilePathProtocol协议
extension URL: FilePathProtocol {
    /// 获取路径字符串
    public func stringPath() -> String {
        return self.path
    }
    /// 获取路径URL
    public func urlPath() -> URL {
        return self
    }
}

// MARK: - 常用目录
public extension FileManager {

    /// documents 文件夹路径
    /// - Parameter pathComponent: 拼接路径
    /// - Returns: 路径URL
    func documentsPath(with pathComponent: String = "") -> URL? {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent(pathComponent)
    }

    /// library 文件夹路径
    /// - Parameter pathComponent: 拼接路径
    /// - Returns: 路径URL
    func libraryPath(with pathComponent: String = "") -> URL? {
        guard let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent(pathComponent)
    }

    /// library/cache 文件夹路径
    /// - Parameter pathComponent: 拼接路径
    /// - Returns: 路径URL
    func cachePath(with pathComponent: String = "") -> URL? {
        guard let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent(pathComponent)
    }

    /// library/Preferences 文件夹路径
    /// - Parameter file: 拼接路径
    /// - Returns: 路径URL
    func applicationSupportPath(with pathComponent: String = "") -> URL? {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        if !FileManager.default.fileExists(atPath: url.absoluteString, isDirectory: nil) {
            do {
                try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return nil
            }
        }
        return url.appendingPathComponent(pathComponent)
    }

    /// tmp 文件夹路径
    /// - Parameter pathComponent: 拼接路径
    /// - Returns: 路径URL
    func temporaryPath(with pathComponent: String = "") -> URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent(pathComponent, isDirectory: false)
    }
}

// MARK: - 文件操作（读、写、删除、移动等等）
public extension FileManager {

    /// 新建文件夹
    /// - Parameter path: 文件夹路径
    /// - Returns: 是否创建成功
    @discardableResult
    func createDirectory(_ path: FilePathProtocol) -> Bool {
        var isDirectory: ObjCBool = false
        let isExisted = FileManager.default.fileExists(atPath: path.stringPath(), isDirectory: &isDirectory)
        if !isDirectory.boolValue || !isExisted {
            do {
                try FileManager.default.createDirectory(at: path.urlPath(), withIntermediateDirectories: true, attributes: nil)
            } catch {
                return false
            }
        }
        return true
    }
    
    /// 新建一个文件
    /// - Parameter path: 指定文件路径 - /tmp/mediaCache/test.mp4
    /// - Returns: 如果路径已存在返回 true，如果创建成功返回 true，如果路径中包含不存在的文件夹返回 false
    @discardableResult
    func createFile(_ path: FilePathProtocol) -> Bool {
        if path.isFileExists {
            return true
        }
        return FileManager.default.createFile(atPath: path.stringPath(), contents: nil, attributes: nil)
    }

    /// 删除文件
    /// - Parameters:
    ///   - file: 文件名
    ///   - path: 文件目录
    /// - Returns: 是否成功
    @discardableResult
    func delete(file: String, from path: FilePathProtocol) -> Bool {
        if !file.isEmpty, FileManager.default.fileExists(atPath: path.urlPath().appendingPathComponent(file).stringPath()) {
            do {
                try FileManager.default.removeItem(atPath: path.urlPath().appendingPathComponent(file).stringPath())
                return true
            } catch {
                return false
            }
        }
        return false
    }

    /// 删除文件
    /// - Parameters:
    ///   - path: 文件路径
    /// - Returns: 是否成功
    @discardableResult
    func delete(atPath: FilePathProtocol) -> Bool {
        if FileManager.default.fileExists(atPath: atPath.stringPath()) {
            do {
                try FileManager.default.removeItem(atPath: atPath.stringPath())
                return true
            } catch {
                return false
            }
        }
        return false
    }

    /// 保存文本
    /// - Parameters:
    ///   - content: 文本内容
    ///   - path: 文件目录
    ///   - file: 文件名
    /// - Returns: 是否成功
    @discardableResult
    func save(_ content: String, to path: FilePathProtocol, file: String) -> Bool {
        createDirectory(path)
        do {
            try content.write(toFile: path.urlPath().appendingPathComponent(file).stringPath(), atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    /// 读取文本
    /// - Parameters:
    ///   - file: 文件名
    ///   - path: 文件目录
    /// - Returns: 文本内容
    func read(file: String, from path: FilePathProtocol) -> String? {
        return try? String(contentsOfFile: path.urlPath().appendingPathComponent(file).stringPath(), encoding: .utf8)
    }

    /// 移动文件
    /// - Parameters:
    ///   - file: 文件名
    ///   - origin: 原目录
    ///   - destination: 目标目录
    /// - Returns: 是否成功
    @discardableResult
    func move(file: String, from origin: FilePathProtocol, to destination: FilePathProtocol) -> Bool {
        let paths = check(file: file, origin: origin, destination: destination)
        if paths.fileExist {
            do {
                try FileManager.default.moveItem(atPath: paths.origin, toPath: paths.destination)
                return true
            } catch {
                return false
            }
        } else {
            return false
        }
    }

    /// 复制文件
    /// - Parameters:
    ///   - file: 文件名
    ///   - origin: 原目录
    ///   - destination: 目标目录
    /// - Returns: 是否成功
    @discardableResult
    func copy(file: String, from origin: FilePathProtocol, to destination: FilePathProtocol) -> Bool {
        let paths = check(file: file, origin: origin, destination: destination)
        if paths.fileExist {
            do {
                try FileManager.default.copyItem(atPath: paths.origin, toPath: paths.destination)
                return true
            } catch {
                return false
            }
        } else {
            return false
        }
    }

    /// 路径检查
    /// - Parameters:
    ///   - file: 文件
    ///   - origin: 原目录
    ///   - destination: 目标目录
    /// - Returns: （原路径，目标路径，文件是否存在）
    private func check(file: String, origin: FilePathProtocol, destination: FilePathProtocol) -> (origin: String, destination: String, fileExist: Bool) {

        let finalOriginPath = origin.urlPath().appendingPathComponent(file).stringPath()
        let finalDestinationPath = destination.urlPath().appendingPathComponent(file).stringPath()

        guard !FileManager.default.fileExists(atPath: finalOriginPath) else {
            return (finalOriginPath, finalDestinationPath, true)
        }

        return (finalOriginPath, finalDestinationPath, false)
    }

    /// 重命名
    /// - Parameters:
    ///   - file: 原文件名
    ///   - origin: 目录
    ///   - newName: 新文件名
    /// - Returns: 是否成功
    @discardableResult
    func rename(file: String, in path: FilePathProtocol, to newName: String) -> Bool {
        let finalOriginPath = path.urlPath().appendingPathComponent(file).stringPath()
        guard FileManager.default.fileExists(atPath: finalOriginPath) else {
            return false
        }
        let destinationPath: String = finalOriginPath.replacingOccurrences(of: file, with: newName)
        do {
            try FileManager.default.copyItem(atPath: finalOriginPath, toPath: destinationPath)
            try FileManager.default.removeItem(atPath: finalOriginPath)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - 缓存相关
public extension FileManager {
    
    /// 计算缓存大小
    /// - Returns: bytes
    func cacheSize(at path: FilePathProtocol, completion: @escaping (_ size: UInt) -> Void) {
        do {
            // 浅遍历指定路径下的文件夹或文件
            let paths = try FileManager.default.contentsOfDirectory(atPath: path.stringPath())
            // 取得指定路径下：文件大小+文件夹大小
            let size = paths.reduce(0) { (result, subpath) -> UInt in
                let subfilePath = path.urlPath().appendingPathComponent(subpath).stringPath()
                guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: subfilePath),
                      let fileSize = fileAttributes[.size] as? UInt else {
                          return result
                      }
                return result + fileSize
            }
            return completion(size)
        } catch {
            completion(0)
        }
    }
}
