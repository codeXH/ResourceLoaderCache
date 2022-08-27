//
//  CwlMutex.swift
//  CwlUtils
//
//  Created by Matt Gallagher on 2015/02/03.
//  Copyright © 2015 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//
//  Permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
//  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
//  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//
// pthread_mutex_t 是一个可选择性地配置为递归锁的阻塞锁；
// pthread_rwlock_t 是一个阻塞读写锁；
// dispatch_queue_t 可以用作阻塞锁，也可以通过使用 barrier block 配置一个同步队列作为读写锁，还支持异步执行加锁代码；
// NSOperationQueue 可以用作阻塞锁。与 dispatch_queue_t 一样，支持异步执行加锁代码。
// NSLock 是 Objective-C 类的阻塞锁，它的同伴类 NSRecursiveLock 是递归锁。
// OSSpinLock 顾名思义，是一个自旋锁。因为会导致优先级反转的问题，iOS 10 中已经被废弃
// @synchronized 是一个阻塞递归锁。

#if os(Linux)
	import Glibc
#else
	import Darwin
#endif

/// A basic mutex protocol that requires nothing more than "performing work inside the mutex".
public protocol ScopedMutex {
	/// Perform work inside the mutex
	func sync<R>(execute work: () throws -> R) rethrows -> R

	/// Perform work inside the mutex, returning immediately if the mutex is in-use
	func trySync<R>(execute work: () throws -> R) rethrows -> R?
}

/// A more specific kind of mutex that assume an underlying primitive and unbalanced lock/trylock/unlock operators
public protocol RawMutex: ScopedMutex {
	associatedtype MutexPrimitive

	var underlyingMutex: MutexPrimitive { get set }

	func unbalancedLock()
	func unbalancedTryLock() -> Bool
	func unbalancedUnlock()
}

public extension RawMutex {
    /// 加锁
    func sync<R>(execute work: () throws -> R) rethrows -> R {
		unbalancedLock()
		defer { unbalancedUnlock() }
		return try work()
	}
    /// 加锁
    func trySync<R>(execute work: () throws -> R) rethrows -> R? {
		guard unbalancedTryLock() else { return nil }
		defer { unbalancedUnlock() }
		return try work()
	}
}

/// A basic wrapper around the "NORMAL" and "RECURSIVE" `pthread_mutex_t` (a general purpose mutex). This type is a "class" type to take advantage of the "deinit" method and prevent accidental copying of the `pthread_mutex_t`.
public final class PThreadMutex: RawMutex {
	public typealias MutexPrimitive = pthread_mutex_t

	// Non-recursive "PTHREAD_MUTEX_NORMAL" and recursive "PTHREAD_MUTEX_RECURSIVE" mutex types.
	public enum PThreadMutexType {
		case normal
		case recursive
	}

	public var underlyingMutex = pthread_mutex_t()

	/// Default constructs as ".Normal" or ".Recursive" on request.
	public init(type: PThreadMutexType = .normal) {
		var attr = pthread_mutexattr_t()
		guard pthread_mutexattr_init(&attr) == 0 else {
			preconditionFailure()
		}
		switch type {
		case .normal:
			pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL)
		case .recursive:
			pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)
		}
		guard pthread_mutex_init(&underlyingMutex, &attr) == 0 else {
			preconditionFailure()
		}
		pthread_mutexattr_destroy(&attr)
	}

	deinit {
		pthread_mutex_destroy(&underlyingMutex)
	}

	public func unbalancedLock() {
		pthread_mutex_lock(&underlyingMutex)
	}

	public func unbalancedTryLock() -> Bool {
		return pthread_mutex_trylock(&underlyingMutex) == 0
	}

	public func unbalancedUnlock() {
		pthread_mutex_unlock(&underlyingMutex)
	}
}

extension PThreadMutex {
    @discardableResult
    func sync_same_file<R>(f: () throws -> R) rethrows -> R {
        pthread_mutex_lock(&underlyingMutex)
        defer { pthread_mutex_unlock(&underlyingMutex) }
        return try f()
    }
}
