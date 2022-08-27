//
//  CacheAction.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/4/14.
//
//  Hashable 是 Equatable 的子类, 所以不需要显式遵守
//  hash(into hasher: inout Hasher) 提供了默认实现

import Foundation

//: 缓存的类型和数据范围
struct CacheAction: Hashable, CustomStringConvertible {

    enum CacheActionType: Equatable {
        case local
        case remote
    }

    var type: CacheActionType
    var range: Range<UInt64>

    init(type: CacheActionType, range: Range<UInt64>) {
        self.type = type
        self.range = range
    }

    // equatable
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.type == rhs.type && lhs.range == rhs.range
    }

    // CustomString
    var description: String {
        return "type \(type), range: \(range)"
    }
}
