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

    @State private var viewModel: ViewModel

    init(modelContext: ModelContext, publicKeyHex: String?) {
        let viewModel = ViewModel(modelContext: modelContext, publicKeyHex: publicKeyHex)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section(
                content: {
                    if let relayPoolSettings = viewModel.relayPoolSettings {
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
                                Picker(relaySettings.relayURLString, selection: relayMarkerBinding) {
                                    ForEach(RelayOption.allCases, id: \.self) { option in
                                        Text(option.localizedStringResource)
                                    }
                                }
                                .pickerStyle(.navigationLink)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        viewModel.removeRelaySettings(relaySettings: relaySettings)
                                    } label: {
                                        Label(.localizable.delete, systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                },
                header: {
                    Text(.localizable.settingsRelays)
                }
            )

            Section {
                TextField(localized: .localizable.exampleRelay, text: $newRelay)
                    .autocorrectionDisabled(false)
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
                            viewModel.addRelay(relayURL: validatedRelayURL)
                        }
                    },
                    label: {
                        Text(.localizable.addRelay)
                    }
                )
                .disabled(!canAddRelay)
            }
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

extension RelaysSettingsView {
    class ViewModel: ObservableObject {
        let publicKeyHex: String?
        var modelContext: ModelContext
        var relayPoolSettings: RelayPoolSettings?

        init(modelContext: ModelContext, publicKeyHex: String?) {
            self.modelContext = modelContext
            self.publicKeyHex = publicKeyHex
            fetchData()
        }

        func addRelay(relayURL: URL) {
            guard let relayPoolSettings, relayPoolSettings.relaySettingsList.allSatisfy({ $0.relayURLString != relayURL.absoluteString }) else {
                return
            }

            relayPoolSettings.relaySettingsList.append(RelaySettings(relayURLString: relayURL.absoluteString))
        }

        func removeRelaySettings(relaySettings: RelaySettings) {
            relayPoolSettings?.relaySettingsList.removeAll(where: { $0 == relaySettings })
        }

        func fetchData() {
            do {
                var descriptor = FetchDescriptor<Profile>(
                    predicate: #Predicate { $0.publicKeyHex == publicKeyHex }
                )
                descriptor.fetchLimit = 1

                let profile = try modelContext.fetch(descriptor).first
                relayPoolSettings = profile?.profileSettings?.relayPoolSettings

            } catch {
                print("Relay settings fetch failed for publicKeyHex=\(publicKeyHex ?? "nil")")
            }
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
