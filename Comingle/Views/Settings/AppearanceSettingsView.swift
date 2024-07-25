//
//  AppearanceSettingsView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/10/24.
//

import SwiftData
import SwiftUI

struct AppearanceSettingsView: View {

    @EnvironmentObject var appState: AppState

    @State private var viewModel: ViewModel

    init(modelContext: ModelContext, publicKeyHex: String?) {
        let viewModel = ViewModel(modelContext: modelContext, publicKeyHex: publicKeyHex)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section(
                content: {
                    Picker(selection: $viewModel.timeZonePreference, label: Text(.localizable.timeZone)) {
                        ForEach(TimeZonePreference.allCases, id: \.self) { preference in
                            Text(preference.localizedStringResource)
                                .tag(preference)
                        }
                    }
                },
                header: {
                    Text(.localizable.settingsAppearance)
                }
            )
        }
    }
}

extension AppearanceSettingsView {
    @Observable class ViewModel {
        let publicKeyHex: String?
        let modelContext: ModelContext
        var appearanceSettings: AppearanceSettings?

        init(modelContext: ModelContext, publicKeyHex: String?) {
            self.modelContext = modelContext
            self.publicKeyHex = publicKeyHex
            fetchData()
        }

        var timeZonePreference: TimeZonePreference {
            get {
                appearanceSettings?.timeZonePreference ?? .event
            }
            set {
                if let appearanceSettings {
                    appearanceSettings.timeZonePreference = newValue
                }
            }
        }

        func fetchData() {
            do {
                var descriptor = FetchDescriptor<Profile>(
                    predicate: #Predicate { $0.publicKeyHex == publicKeyHex }
                )
                descriptor.fetchLimit = 1

                if let profile = try modelContext.fetch(descriptor).first {
                    // FIXME
                    if let appearanceSettings = profile.profileSettings?.appearanceSettings {
                        self.appearanceSettings = appearanceSettings
                    }
                } else {
                    let newProfile = Profile()
                    modelContext.insert(newProfile)
                    try modelContext.save()
                }
            } catch {
                print("Appearance settings fetch failed for publicKeyHex=\(publicKeyHex ?? "nil")")
            }
        }
    }
}

//#Preview {
//    AppearanceSettingsView()
//}
