//
//  KeysSettingsView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/10/24.
//

import Combine
import LocalAuthentication
import NostrSDK
import SwiftUI

struct KeysSettingsView: View {

    let publicKey: PublicKey
    @State private var privateKeyNsec: String = ""

    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section(
                content: {
                    Text(publicKey.npub)
                },
                header: {
                    Text(.localizable.publicKey)
                }
            )

            Section(
                content: {
                    SecureField(.localizable.tapToEnterPrivateKey, text: $privateKeyNsec)
                        .disabled(true)
                },
                header: {
                    Text(.localizable.privateKey)
                }
            )
        }
        .task {
            privateKeyNsec = appState.privateKeySecureStorage.keypair(for: publicKey)?.privateKey.nsec ?? ""
        }
    }
}

#Preview {
    KeysSettingsView(publicKey: PublicKey(hex: "c3e6982c7f93e443d99f2d22c3d6fc6ba61475af11bcf289f927a7b905fffe51")!)
}
