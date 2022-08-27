//
//  Log+Extension.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/4/20.
//

import Foundation

func log<T>(_ message: T, file: String = #file, lineNumber: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    print("[\(fileName)] -- line:\(lineNumber) -- \(message)")
    #endif
}
