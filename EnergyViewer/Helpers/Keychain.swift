//
//  Keychain.swift
//  EnergyViewer
//
//  Created by Peter Bohac on 10/28/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import Security

struct Keychain {
    struct Key<Value> {
        var name: String
    }

    enum Error: Swift.Error {
        case failure(status: Int32, message: String)
        case badFormat
    }

    private static let jsonEncoder = JSONEncoder()
    private static let jsonDecoder = JSONDecoder()

    subscript<T: Codable>(_ key: Key<T>) -> T? {
        get {
            try? object(for: key)
        }

        set {
            if let val = newValue {
                if try! valueExists(for: key) { try! update(value: val, for: key) }
                else { try! insert(value: val, for: key) }
            } else {
                try! removeValue(for: key)
            }
        }
    }

    func allKeys() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]
        var items: AnyObject?
        let result = SecItemCopyMatching(query as CFDictionary, &items)
        if result == errSecSuccess, let itemsArray = items as? [[String: Any]] {
            return itemsArray.compactMap { $0[kSecAttrService as String] as? String }
        } else {
            let msg = SecCopyErrorMessageString(result, nil) as String? ?? "<none>"
            print("allKeys() failed with \(result): \(msg)")
            throw Error.failure(status: result, message: msg)
        }
    }

    func object<T: Codable>(for key: Key<T>) throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.name,
            kSecMatchLimit as String: 1,
            kSecReturnData as String: true,
        ]
        var item: AnyObject?
        let result = SecItemCopyMatching(query as CFDictionary, &item)
        if result == errSecSuccess {
            guard let data = item as? Data else { throw Error.badFormat }
            return try Self.jsonDecoder.decode(T.self, from: data)
        } else if result == errSecItemNotFound {
            print("object(for: \(key.name)) not found")
            return nil
        } else {
            let msg = SecCopyErrorMessageString(result, nil) as String? ?? "<none>"
            print("object(for: \(key.name)) failed with \(result): \(msg)")
            throw Error.failure(status: result, message: msg)
        }
    }

    func valueExists<T>(for key: Key<T>) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.name,
            kSecMatchLimit as String: 1,
        ]
        var item: AnyObject?
        let result = SecItemCopyMatching(query as CFDictionary, &item)
        if result == errSecSuccess {
            return true
        } else if result == errSecItemNotFound {
            return false
        } else {
            let msg = SecCopyErrorMessageString(result, nil) as String? ?? "<none>"
            print("valueExists(for: \(key.name)) failed with \(result): \(msg)")
            throw Error.failure(status: result, message: msg)
        }
    }

    func insert<T: Codable>(value: T, for key: Key<T>) throws {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.name,
            kSecValueData as String: try Self.jsonEncoder.encode(value)
        ]
        let result = SecItemAdd(attributes as CFDictionary, nil)
        if result != errSecSuccess {
            let msg = SecCopyErrorMessageString(result, nil) as String? ?? "<none>"
            print("insert(value: T, for: \(key.name)) failed with \(result): \(msg)")
            throw Error.failure(status: result, message: msg)
        }
    }

    func update<T: Codable>(value: T, for key: Key<T>) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.name,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: try Self.jsonEncoder.encode(value)
        ]
        let result = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if result != errSecSuccess {
            let msg = SecCopyErrorMessageString(result, nil) as String? ?? "<none>"
            print("update(value: T, for: \(key.name)) failed with \(result): \(msg)")
            throw Error.failure(status: result, message: msg)
        }
    }

    func removeValue<T>(for key: Key<T>) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.name,
        ]
        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            let msg = SecCopyErrorMessageString(result, nil) as String? ?? "<none>"
            print("removeValue(for: \(key)) failed with \(result): \(msg)")
            throw Error.failure(status: result, message: msg)
        }
    }
}
