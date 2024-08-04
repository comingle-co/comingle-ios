//
//  LoginView.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import Combine
import NostrSDK
import SwiftData
import SwiftUI

struct LoginView: View, RelayURLValidating {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ViewModel

    @State private var nostrIdentifier: String = ""
    @State private var primaryRelay: String = ""

    @State private var validKey: Bool = false
    @State private var validatedRelayURL: URL?

    @State private var keypair: Keypair?
    @State private var publicKey: PublicKey?

    init(appState: AppState) {
        let viewModel = ViewModel(appState: appState)
        _viewModel = State(initialValue: viewModel)
    }

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
        guard let validatedRelayURL else {
            return
        }

        if let keypair {
            viewModel.login(keypair: keypair, relayURL: validatedRelayURL)
            dismiss()
        } else if let publicKey {
            viewModel.login(publicKey: publicKey, relayURL: validatedRelayURL)
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
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

                                validatedRelayURL = try? validateRelayURLString(filtered)
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
            .disabled(!validKey || validatedRelayURL == nil)
        }
    }
}

extension LoginView {
    @Observable class ViewModel: RelayURLValidating {
        let appState: AppState

        init(appState: AppState) {
            self.appState = appState
        }

        func login(keypair: Keypair, relayURL: URL) {
            appState.privateKeySecureStorage.store(for: keypair)
            login(publicKey: keypair.publicKey, relayURL: relayURL)
        }

        func login(publicKey: PublicKey, relayURL: URL) {
            guard let appSettings = appState.appSettings, appSettings.activeProfile?.publicKeyHex != publicKey.hex, let validatedRelayURL = try? validateRelayURL(relayURL) else {
                return
            }

            if let profile = appState.profiles.first(where: { $0.publicKeyHex == publicKey.hex }) {
                print("Found existing profile settings for \(publicKey.npub)")
                if let relayPoolSettings = profile.profileSettings?.relayPoolSettings,
                   !relayPoolSettings.relaySettingsList.contains(where: { URL(string: $0.relayURLString) == validatedRelayURL }) {
                    relayPoolSettings.relaySettingsList.append(RelaySettings(relayURLString: validatedRelayURL.absoluteString))
                }
                appSettings.activeProfile = profile
            } else {
                print("Creating new profile settings for \(publicKey.npub)")
                let profile = Profile(publicKeyHex: publicKey.hex)
                appState.modelContext.insert(profile)
                do {
                    try appState.modelContext.save()
                } catch {
                    print("Unable to save new profile \(publicKey.npub)")
                }
                appState.profiles.append(profile)
                if let relayPoolSettings = profile.profileSettings?.relayPoolSettings,
                   !relayPoolSettings.relaySettingsList.contains(where: { URL(string: $0.relayURLString) == validatedRelayURL }) {
                    relayPoolSettings.relaySettingsList.append(RelaySettings(relayURLString: validatedRelayURL.absoluteString))
                }
                appSettings.activeProfile = profile
            }

            appState.refreshFollowedPubkeys()
            appState.pullMissingEventsFromFollows([publicKey.hex])
            appState.updateRelayPool()
            appState.refresh()
        }
    }
}

//struct LoginView_Previews: PreviewProvider {
//
//    @State static var appState = AppState()
//
//    static var previews: some View {
//        LoginView()
//            .environmentObject(appState)
//    }
//}
