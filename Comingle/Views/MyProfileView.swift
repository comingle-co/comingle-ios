//
//  MyProfileView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/7/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct MyProfileView: View {

    @EnvironmentObject var appState: AppState

    @State private var showProfileSwitcher: Bool = false

    var body: some View {
        VStack {
            Section(
                isExpanded: $showProfileSwitcher,
                content: {
                    if let appSettings = appState.appSettings {
                        let profiles = appSettings.profiles.filter { $0 != appState.appSettings?.activeProfile }
                        VStack(alignment: .leading) {
                            ForEach(profiles, id: \.self) { profile in
                                ProfileSmallView(publicKeyHex: profile.publicKeyHex)
                                    .environmentObject(appState)
                                    .onTapGesture {
                                        appSettings.activeProfile = profile
                                        showProfileSwitcher = false
                                    }
                            }
                        }
                    }
                },
                header: {
                    ProfileSmallView(publicKeyHex: appState.appSettings?.activeProfile?.publicKeyHex)
                        .onTapGesture {
                            showProfileSwitcher.toggle()
                        }
                }
            )

            CalendarEventListView(calendarEventListType: .profile)
        }
    }
}

struct MyProfileView_Previews: PreviewProvider {

    @State static var appState = AppState()

    static var previews: some View {
        MyProfileView()
            .environmentObject(appState)
    }
}
