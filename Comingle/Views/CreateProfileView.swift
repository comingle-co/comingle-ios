//
//  CreateProfileView.swift
//  Comingle
//
//  Created by Terry Yiu on 8/4/24.
//

import Kingfisher
import NostrSDK
import OrderedCollections
import SwiftUI

struct CreateProfileView: View, EventCreating {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var appState: AppState

    @State private var credentialHandler: CredentialHandler

    @State private var keypair: Keypair = Keypair.init()!

    @State private var username: String = ""
    @State private var about: String = ""
    @State private var picture: String = ""
    @State private var displayName: String = ""

    @State private var hasCopiedPublicKey: Bool = false
    @State private var hasCopiedPrivateKey: Bool = false

    init(appState: AppState) {
        credentialHandler = CredentialHandler(appState: appState)
    }

    var validatedPictureURL: URL? {
        guard let url = URL(string: picture.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        return url
    }

    var canSave: Bool {
        return username.trimmedOrNilIfEmpty != nil && (picture.trimmedOrNilIfEmpty == nil || validatedPictureURL != nil)
    }

    var body: some View {
        Form {
            Section {
                Button(action: {
                    UIPasteboard.general.string = keypair.publicKey.npub
                    hasCopiedPublicKey = true
                }, label: {
                    HStack {
                        Text(keypair.publicKey.npub)
                            .textContentType(.username)
                            .disabled(true)
                            .lineLimit(2)
                            .minimumScaleFactor(0.1)

                        if hasCopiedPublicKey {
                            Image(systemName: "doc.on.doc.fill")
                        } else {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                })
            } header: {
                Text(.localizable.publicKey)
            } footer: {
                Text(.localizable.createPublicKeyFooter)
            }

            Section {
                Button(action: {
                    UIPasteboard.general.string = keypair.privateKey.nsec
                    hasCopiedPrivateKey = true
                }, label: {
                    HStack {
                        Text(keypair.privateKey.nsec)
                            .textContentType(.newPassword)
                            .disabled(true)
                            .lineLimit(2)
                            .minimumScaleFactor(0.1)

                        if hasCopiedPrivateKey {
                            Image(systemName: "doc.on.doc.fill")
                        } else {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                })
            } header: {
                Text(.localizable.privateKey)
            } footer: {
                Text(.localizable.createPrivateKeyFooter)
            }

            Section {
                TextField(localized: .localizable.username, text: $username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text(.localizable.username)
            } footer: {
                Text(.localizable.createUsernameFooter)
            }

            Section {
                TextField(localized: .localizable.displayName, text: $displayName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text(.localizable.displayName)
            } footer: {
                Text(.localizable.createDisplayNameFooter)
            }

            Section {
                TextField(localized: .localizable.exampleImage, text: $picture)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if let validatedPictureURL {
                    KFImage.url(validatedPictureURL)
                        .resizable()
                        .placeholder { ProgressView() }
                        .scaledToFit()
                        .frame(maxWidth: 100, maxHeight: 200)
                }
            } header: {
                Text(.localizable.profilePicture)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    credentialHandler.saveCredential(keypair: keypair)
                    appState.privateKeySecureStorage.store(for: keypair)
                    let userMetadata = UserMetadata(name: username.trimmedOrNilIfEmpty, displayName: displayName.trimmedOrNilIfEmpty, pictureURL: validatedPictureURL)

                    do {
                        let readRelayURLs = appState.relayReadPool.relays.map { $0.url }
                        let writeRelayURLs = appState.relayWritePool.relays.map { $0.url }

                        let metadataEvent = try metadataEvent(withUserMetadata: userMetadata, signedBy: keypair)
                        let followListEvent = try followList(withPubkeys: [keypair.publicKey.hex], signedBy: keypair)
                        appState.relayWritePool.publishEvent(metadataEvent)
                        appState.relayWritePool.publishEvent(followListEvent)

                        let persistentNostrEvents = [
                            PersistentNostrEvent(nostrEvent: metadataEvent),
                            PersistentNostrEvent(nostrEvent: followListEvent)
                        ]
                        persistentNostrEvents.forEach {
                            appState.modelContext.insert($0)
                        }

                        try appState.modelContext.save()

                        appState.loadPersistentNostrEvents(persistentNostrEvents)

                        appState.signIn(keypair: keypair, relayURLs: Array(Set(readRelayURLs + writeRelayURLs)))
                    } catch {
                        print("Unable to publish or save MetadataEvent for new profile \(keypair.publicKey.npub).")
                    }

                    dismiss()
                }, label: {
                    Text(.localizable.createProfile)
                })
                .disabled(!canSave)
            }
        }
    }
}

//#Preview {
//    CreateProfileView()
//}
