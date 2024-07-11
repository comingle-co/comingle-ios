//
//  LoginView.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import Combine
import NostrSDK
import SwiftUI

struct LoginView: View, RelayURLValidating {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var nostrIdentifier: String = "npub1yaul8k059377u9lsu67de7y637w4jtgeuwcmh5n7788l6xnlnrgs3tvjmf"
    @State private var primaryRelay: String = AppState.defaultRelayURLString

    @State private var validKey: Bool = false
    @State private var validRelay: Bool = false

    @State private var keypair: Keypair?
    @State private var publicKey: PublicKey?

    private func relayFooter() -> AttributedString {
        var footer = AttributedString(localized: .localizable.tryDefaultRelay(AppState.defaultRelayURLString))
        if let range = footer.range(of: AppState.defaultRelayURLString) {
            footer[range].underlineStyle = .single
            footer[range].foregroundColor = .blue
        }

        return footer
    }

    private func isValidRelay(address: String) -> Bool {
        (try? validateRelayURLString(address)) != nil
    }

    @MainActor
    private func login() {
        guard let appSettings = appState.appSettings, let publicKey else {
            return
        }

        if let keypair {
            appState.privateKeySecureStorage.store(for: keypair)
        }

        if let profile = appSettings.profiles.first(where: { $0.publicKeyHex == publicKey.hex }) {
            print("Found existing profile settings for \(publicKey.npub)")
            if validRelay {
                profile.profileSettings?.relaySettings?.relayURLStrings.append(primaryRelay)
            }
            appSettings.activeProfile = profile
        } else {
            print("Creating new profile settings for \(publicKey.npub)")
            let profile = Profile(publicKeyHex: publicKey.hex)
            appSettings.profiles.append(profile)
            if validRelay {
                profile.profileSettings?.relaySettings?.relayURLStrings = [primaryRelay]
            }
            appSettings.activeProfile = profile
        }

        dismiss()
    }

    var body: some View {
        NavigationStack {
            Image("ComingleLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 300)

            Form {
                Section(
                    content: {
                        TextField(localized: .localizable.exampleRelay, text: $primaryRelay)
                            .autocorrectionDisabled(false)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onReceive(Just(primaryRelay)) { newValue in
                                let filtered = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                primaryRelay = filtered

                                if filtered.isEmpty {
                                    return
                                }

                                validRelay = isValidRelay(address: filtered)
                            }
                    },
                    header: {
                        Text(.localizable.primaryNostrRelayRequired)
                    },
                    footer: {
                        Text(relayFooter())
                            .onTapGesture {
                                primaryRelay = AppState.defaultRelayURLString
                            }
                    }
                )

                Section(
                    content: {
                        SecureField(.localizable.enterNostrKey, text: $nostrIdentifier)
                            .autocorrectionDisabled(false)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .onReceive(Just(nostrIdentifier)) { newValue in
                                let filtered = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                nostrIdentifier = filtered

                                if let keypair = Keypair(nsec: filtered) {
                                    self.keypair = keypair
                                    self.publicKey = keypair.publicKey
                                    validKey = true
                                } else if let publicKey = PublicKey(npub: filtered) {
                                    self.keypair = nil
                                    self.publicKey = publicKey
                                    validKey = true
                                } else {
                                    self.keypair = nil
                                    self.publicKey = nil
                                    validKey = false
                                }
                            }
                    },
                    header: {
                        Text(.localizable.nostrKeyHeader)
                    },
                    footer: {
                        if keypair != nil {
                            Text(.localizable.nostrPrivateKeyEnteredFooter)
                        } else if publicKey != nil {
                            Text(.localizable.nostrPublicKeyFooter)
                        }
                    }
                )
            }

            Button(.localizable.findMeOnNostr) {
                login()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!validKey || !validRelay)
        }
    }
}

struct LoginView_Previews: PreviewProvider {

    @State static var appState = AppState()

    static var previews: some View {
        LoginView()
            .environmentObject(appState)
    }
}
