//
//  ContentView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/9/23.
//

import Kingfisher
import NostrSDK
import SwiftData
import SwiftUI

struct ContentView: View {

    let modelContext: ModelContext
    @EnvironmentObject var appState: AppState

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var body: some View {
        NavigationStack {
            VStack {
                TabView(selection: $appState.activeTab) {
                    if appState.publicKey != nil {
                        NavigationStack {
                            HomeView(modelContext: modelContext, appState: appState)
                        }
                        .tabItem {
                            Label(.localizable.home, systemImage: "house")
                        }
                        .tag(HomeTabs.following)
                    }

                    NavigationStack {
                        EventListView(eventListType: .all)
                            .navigationTitle(.localizable.explore)
                    }
                    .tabItem {
                        Label(.localizable.explore, systemImage: "magnifyingglass")
                    }
                    .tag(HomeTabs.explore)
                }
            }
            .toolbar {
                NavigationLink(
                    destination: {
                        SettingsView(modelContext: modelContext, appState: appState)
                    },
                    label: {
                        if let publicKey = appState.publicKey {
                            if appState.keypair != nil {
                                ProfilePictureView(publicKeyHex: publicKey.hex)
                            } else {
                                ProfilePictureView(publicKeyHex: publicKey.hex)
                                    .overlay(
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(.secondary)
                                            .frame(width: 16, height: 16)
                                            .offset(x: 4, y: 4),
                                        alignment: .bottomTrailing
                                    )
                            }
                        } else {
                            GuestProfilePictureView()
                                .overlay(
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.secondary)
                                        .frame(width: 16, height: 16)
                                        .offset(x: 4, y: 4),
                                    alignment: .bottomTrailing
                                )
                        }
                    }
                )
            }
        }
    }
}

//struct ContentView_Previews: PreviewProvider {
//
//    @State static var appState = AppState()
//
//    static var previews: some View {
//        ContentView()
//            .environmentObject(appState)
//            .modelContainer(for: [AppSettings.self])
//    }
//}
