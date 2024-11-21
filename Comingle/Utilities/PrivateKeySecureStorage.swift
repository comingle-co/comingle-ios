//
//  PrivateKeySecureStorage.swift
//  Comingle
//
//  Created by Terry Yiu on 7/6/24.
//

import Foundation
import NostrSDK
import Security

class PrivateKeySecureStorage {

    static let shared = PrivateKeySecureStorage()

    private let service = "comingle-private-keys"

    func keypair(for publicKey: PublicKey) -> Keypair? {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: publicKey.hex,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [CFString: Any] as CFDictionary

        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)

        if status == errSecSuccess, let data = result as? Data, let privateKeyHex = String(data: data, encoding: .utf8) {
            return Keypair(hex: privateKeyHex)
        } else {
            return nil
        }
    }

    func store(for keypair: Keypair) {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: keypair.publicKey.hex,
            kSecClass: kSecClassGenericPassword,
            kSecValueData: keypair.privateKey.hex.data(using: .utf8) as Any
        ] as [CFString: Any] as CFDictionary

        var status = SecItemAdd(query, nil)

        if status == errSecDuplicateItem {
            let query = [
                kSecAttrService: service,
                kSecAttrAccount: keypair.publicKey.hex,
                kSecClass: kSecClassGenericPassword
            ] as [CFString: Any] as CFDictionary

            let updates = [
                kSecValueData: keypair.privateKey.hex.data(using: .utf8) as Any
            ] as CFDictionary

            status = SecItemUpdate(query, updates)
        }
    }

    func delete(for publicKey: PublicKey) {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: publicKey.hex,
            kSecClass: kSecClassGenericPassword
        ] as [CFString: Any] as CFDictionary

        _ = SecItemDelete(query)
    }
}
