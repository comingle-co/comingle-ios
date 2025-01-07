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
                    Picker(selection: $viewModel.timeZonePreference, label: Text("Time Zone", comment: "Label for time zone setting.")) {
                        ForEach(TimeZonePreference.allCases, id: \.self) { preference in
                            Text(preference.localizedString)
                                .tag(preference)
                        }
                    }
                },
                header: {
                    Text("Appearance", comment: "Settings section for appearance of the app.")
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
                var descriptor = FetchDescriptor<AppearanceSettings>(
                    predicate: #Predicate { $0.publicKeyHex == publicKeyHex }
                )
                descriptor.fetchLimit = 1

                self.appearanceSettings = try modelContext.fetch(descriptor).first
            } catch {
                print("Appearance settings fetch failed for publicKeyHex=\(publicKeyHex ?? "nil")")
            }
        }
    }
}

//#Preview {
//    AppearanceSettingsView()
//}
