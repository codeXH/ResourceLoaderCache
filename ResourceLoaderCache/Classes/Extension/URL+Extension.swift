//
//  URL+Extension.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/6/21.
//

import Foundation

extension URL {
    
    /// 替换链接 scheme
    /// - Parameter scheme: http://www.baidu.com  -> streaming://www.baidu.com
    func replaceScheme(with scheme: String = "streaming") -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = scheme
        return components.url
    }
}
