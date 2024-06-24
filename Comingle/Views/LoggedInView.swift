//
//  LoggedInView.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import SwiftUI

struct LoggedInView: View {

    @EnvironmentObject var appState: AppState

    @State private var selectedTab: HomeTabs = .following

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
                    .environmentObject(appState)
            }
//            NavigationStack {
//                CalendarsView()
//                    .navigationTitle(.localizable.calendars)
//                    .toolbar {
//                        ToolbarItem(placement: .primaryAction) {
//                            NavigationLink(destination: SettingsView()) {
//                                Image(systemName: "gear")
//                            }
//                        }
//                    }
//            }
            .tabItem {
                Label(.localizable.home, systemImage: "house")
            }
            .tag(HomeTabs.following)

            NavigationStack {
                CalendarsView()
                    .navigationTitle(.localizable.calendars)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            NavigationLink(destination: SettingsView()) {
                                Image(systemName: "gear")
                            }
                        }
                    }
            }
            .tabItem {
                Label(.localizable.explore, systemImage: "magnifyingglass")
            }
            .tag(HomeTabs.explore)
        }
//        NavigationStack {
//            CalendarsView()
//                .navigationTitle(.localizable.calendars)
//                .toolbar {
//                    ToolbarItem(placement: .primaryAction) {
//                        NavigationLink(destination: SettingsView()) {
//                            Image(systemName: "gear")
//                        }
//                    }
//                }
//        }
    }
}

enum HomeTabs {
    case following
    case explore
}

struct LoggedInView_Previews: PreviewProvider {
    static var appState = AppState()

    static var previews: some View {
        LoggedInView()
            .environmentObject(appState)
    }
}
