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

    @State private var validPrivateKey: Bool = false

    @State private var incorrectPrivateKeyAlertPresented: Bool = false

    @State private var hasCopiedPublicKey: Bool = false

    var body: some View {
        List {
            Section(
                content: {
                    HStack {
                        Button(action: {
                            UIPasteboard.general.string = publicKey.npub
                            hasCopiedPublicKey = true
                        }, label: {
                            HStack {
                                Text(publicKey.npub)
                                    .textContentType(.username)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.1)

                                if hasCopiedPublicKey {
                                    Image(systemName: "doc.on.doc.fill")
                                } else {
                                    Image(systemName: "doc.on.doc")
                                }
                            }
                        })
                        .foregroundStyle(.primary)
                    }
                },
                header: {
                    Text(.localizable.publicKey)
                }
            )

            Section(
                content: {
                    HStack {
                        SecureField(.localizable.privateKeyPlaceholder, text: $privateKeyNsec)
                            .disabled(validPrivateKey)
                            .autocorrectionDisabled(false)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .onReceive(Just(privateKeyNsec)) { newValue in
                                let filtered = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                privateKeyNsec = filtered

                                if let keypair = Keypair(nsec: filtered) {
                                    if keypair.publicKey == publicKey {
                                        appState.privateKeySecureStorage.store(for: keypair)
                                        privateKeyNsec = keypair.privateKey.nsec
                                        validPrivateKey = true
                                    } else {
                                        validPrivateKey = false
                                        incorrectPrivateKeyAlertPresented = true
                                    }
                                } else {
                                    validPrivateKey = false
                                }
                            }
                    }
                },
                header: {
                    Text(.localizable.privateKey)
                },
                footer: {
                    if validPrivateKey {
                        Text(.localizable.nostrPrivateKeyEnteredFooter)
                    } else if privateKeyNsec.isEmpty {
                        Text(.localizable.nostrPrivateKeyMissingFooter)
                    } else {
                        Text(.localizable.nostrPrivateKeyIncorrectFooter)
                    }
                }
            )
        }
        .alert(
            Text(.localizable.privateKeyMismatch),
            isPresented: $incorrectPrivateKeyAlertPresented
        ) {
            Button(.localizable.ok) {
                privateKeyNsec = ""
            }
        }
        .task {
            if let nsec = appState.privateKeySecureStorage.keypair(for: publicKey)?.privateKey.nsec {
                privateKeyNsec = nsec
                validPrivateKey = true
            } else {
                privateKeyNsec = ""
                validPrivateKey = false
            }
        }
    }
}

#Preview {
    KeysSettingsView(publicKey: PublicKey(hex: "c3e6982c7f93e443d99f2d22c3d6fc6ba61475af11bcf289f927a7b905fffe51")!)
}
