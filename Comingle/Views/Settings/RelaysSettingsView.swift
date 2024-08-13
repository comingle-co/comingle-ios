//
//  RelaysSettingsView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/10/24.
//

import Combine
import NostrSDK
import SwiftData
import SwiftUI

struct RelaysSettingsView: View, RelayURLValidating {
    @EnvironmentObject var appState: AppState

    @State private var validatedRelayURL: URL?
    @State private var newRelay: String = ""

    var body: some View {
        List {
            Section(
                content: {
                    if let relayPoolSettings = appState.relayPoolSettings {
                        ForEach(relayPoolSettings.relaySettingsList, id: \.self) { relaySettings in
                            HStack {
                                let relayMarkerBinding = Binding<RelayOption>(
                                    get: {
                                        switch (relaySettings.read, relaySettings.write) {
                                        case (true, true):
                                                .readAndWrite
                                        case (true, false):
                                                .read
                                        case (false, true):
                                                .write
                                        default:
                                                .read
                                        }
                                    },
                                    set: {
                                        switch $0 {
                                        case .readAndWrite:
                                            relaySettings.read = true
                                            relaySettings.write = true
                                        case .read:
                                            relaySettings.read = true
                                            relaySettings.write = false
                                        case .write:
                                            relaySettings.read = false
                                            relaySettings.write = true
                                        }
                                    }
                                )
                                switch appState.relayState(relayURLString: relaySettings.relayURLString) {
                                case .connected:
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(.green)
                                case .connecting:
                                    Image(systemName: "hourglass.circle")
                                        .foregroundStyle(.yellow)
                                case .error:
                                    Image(systemName: "x.circle.fill")
                                        .foregroundStyle(.red)
                                case .notConnected, .none:
                                    Image(systemName: "pause.circle")
                                        .foregroundStyle(.red)
                                }
                                Picker(relaySettings.relayURLString, selection: relayMarkerBinding) {
                                    ForEach(RelayOption.allCases, id: \.self) { option in
                                        Text(option.localizedStringResource)
                                    }
                                }
                                .pickerStyle(.navigationLink)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        appState.removeRelaySettings(relaySettings: relaySettings)
                                    } label: {
                                        Label(.localizable.delete, systemImage: "trash")
                                    }
                                }
                            }
                        }

                        HStack {
                            TextField(localized: .localizable.exampleRelay, text: $newRelay)
                                .textContentType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onReceive(Just(newRelay)) { newValue in
                                    let filtered = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    newRelay = filtered

                                    if filtered.isEmpty {
                                        return
                                    }

                                    validatedRelayURL = try? validateRelayURLString(filtered)
                                }

                            Button(
                                action: {
                                    if let validatedRelayURL, canAddRelay {
                                        appState.addRelay(relayURL: validatedRelayURL)
                                        newRelay = ""
                                    }
                                },
                                label: {
                                    Image(systemName: "plus.circle")
                                }
                            )
                            .disabled(!canAddRelay)
                        }
                    }
                },
                header: {
                    Text(.localizable.settingsRelays)
                },
                footer: {
                    Text(.localizable.settingsRelayFooter)
                }
            )
        }
    }

    var canAddRelay: Bool {
        guard let validatedRelayURL, let relaySettingsList = appState.appSettings?.activeProfile?.profileSettings?.relayPoolSettings?.relaySettingsList, !relaySettingsList.contains(where: { $0.relayURLString == validatedRelayURL.absoluteString }) else {
            return false
        }
        return true
    }
}

enum RelayOption: CaseIterable {
    case read
    case write
    case readAndWrite

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .read:
                .localizable.relayRead
        case .write:
                .localizable.relayWrite
        case .readAndWrite:
                .localizable.relayReadAndWrite
        }
    }
}

//#Preview {
//    let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
//
//    guard let modelContainer = try? ModelContainer(for: Profile.self, configurations: modelConfiguration), let publicKey = Keypair() else {
//        EmptyView()
//    }
//
//    RelaysSettingsView(modelContext: modelContainer.mainContext, publicKeyHex: publicKey.publicKey.hex)
//}
