//
//  AppearanceSettingsView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/10/24.
//

import SwiftUI

struct AppearanceSettingsView: View {

    @EnvironmentObject var appState: AppState

    @State private var timeZonePreference: TimeZonePreference = .system

    var body: some View {
        List {
            Section(
                content: {
                    Picker(selection: $timeZonePreference, label: Text(.localizable.timeZone)) {
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
        .onChange(of: timeZonePreference) { _, newValue in
            if let appearance = appState.appSettings?.activeProfile?.profileSettings?.appearance {
                appearance.timeZonePreference = newValue
            }
        }
        .task {
            if let appearance = appState.appSettings?.activeProfile?.profileSettings?.appearance {
                timeZonePreference = appearance.timeZonePreference
            }
        }
    }
}

#Preview {
    AppearanceSettingsView()
}
