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
        ScrollViewReader { scrollViewProxy in
            NavigationStack {
                VStack {
                    if appState.publicKey != nil && appState.activeTab == .following {
                        NavigationStack {
                            HomeView(modelContext: modelContext, appState: appState)
                        }
                    }

                    if appState.activeTab == .explore {
                        NavigationStack {
                            EventListView(eventListType: .all)
                                .navigationTitle(.localizable.explore)
                        }
                    }
                    CustomTabBar(selectedTab: $appState.activeTab, showFollowingTab: appState.publicKey != nil) {
                        withAnimation {
                            scrollViewProxy.scrollTo("event-list-view-top")
                        }
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
}

struct CustomTabBar: View {
    @Binding var selectedTab: HomeTabs

    let showFollowingTab: Bool
    let onTapAction: () -> Void

    var body: some View {
        HStack {
            if showFollowingTab {
                CustomTabBarItem(iconName: "house.fill", title: .localizable.home, tab: HomeTabs.following, selectedTab: $selectedTab, onTapAction: onTapAction)
            }
            CustomTabBarItem(iconName: "magnifyingglass", title: .localizable.explore, tab: HomeTabs.explore, selectedTab: $selectedTab, onTapAction: onTapAction)
        }
        .frame(height: 50)
        .background(Color.gray.opacity(0.2))
    }
}

struct CustomTabBarItem: View {
    let iconName: String
    let title: LocalizedStringResource
    let tab: HomeTabs
    @Binding var selectedTab: HomeTabs

    let onTapAction: () -> Void

    var body: some View {
        VStack {
            Image(systemName: iconName)
                .resizable()
                .scaledToFill()
                .frame(width: 20, height: 20)
            Text(title)
                .font(.caption)
        }
        .padding()
        .onTapGesture {
            selectedTab = tab
            onTapAction()
        }
        .foregroundColor(selectedTab == tab ? .accent : .gray)
        .frame(maxWidth: .infinity)
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
