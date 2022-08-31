//
//  Either.swift
//  ResourceLoaderCache
//
//  Created by jianyun zhang on 2022/8/31.
//

import Foundation

enum Either<T, U> {
    case left(T)
    case right(U)
}
