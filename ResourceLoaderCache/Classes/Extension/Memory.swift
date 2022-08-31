//
//  Memory.swift
//  ResourceLoaderCache
//
//  Created by jianyun zhang on 2022/8/31.
//

import Foundation
// https://stackoverflow.com/a/45777692/5536516

struct MemoryAddress<T>: CustomStringConvertible {

    let intValue: Int

    var description: String {
        let length = 2 + 2 * MemoryLayout<UnsafeRawPointer>.size
        return String(format: "%0\(length)p", intValue)
    }

    // for structures
    init(of structPointer: UnsafePointer<T>) {
        intValue = Int(bitPattern: structPointer)
    }
}

extension MemoryAddress where T: AnyObject {

    // for classes
    init(of classInstance: T) {
        intValue = unsafeBitCast(classInstance, to: Int.self)
        // or      Int(bitPattern: Unmanaged<T>.passUnretained(classInstance).toOpaque())
    }
}

/* Testing */

//class MyClass { let foo = 42 }
//var classInstance = MyClass()
//let classInstanceAddress = MemoryAddress(of: classInstance) // and not &classInstance
//print(String(format: "%018p", classInstanceAddress.intValue))
//print(classInstanceAddress)
//
//struct MyStruct { let foo = 1 } // using empty struct gives weird results (see StackOverflow comments)
//var structInstance = MyStruct()
//let structInstanceAddress = MemoryAddress(of: &structInstance)
//print(String(format: "%018p", structInstanceAddress.intValue))
//print(structInstanceAddress)

/* output
0x0000000101916c80
0x0000000101916c80
0x00000001005e3000
0x00000001005e3000
*/
