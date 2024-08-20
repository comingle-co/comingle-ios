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

    @State var isShowingCreationConfirmation: Bool = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var body: some View {
        ScrollViewReader { scrollViewProxy in
            NavigationStack {
                VStack {
                    if appState.activeTab == .events {
                        NavigationStack {
                            EventListView(eventListType: .all)
                                .navigationBarTitleDisplayMode(.inline)
                        }
                    }

                    if appState.activeTab == .calendars {
                        NavigationStack {
                            CalendarsView()
                        }
                    }

                    CustomTabBar(selectedTab: $appState.activeTab, isSignedIn: appState.publicKey != nil) {
                        withAnimation {
                            scrollViewProxy.scrollTo("event-list-view-top")
                        }
                    }
                }
                .confirmationDialog(String(localized: "Create a ..."), isPresented: $isShowingCreationConfirmation) {
                    addEventConfirmationDialogAction()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            isShowingCreationConfirmation = true
                        }, label: {
                            Image(systemName: "plus.circle")
                                .opacity(appState.keypair != nil ? 1 : 0)
                        })
                        .disabled(appState.keypair == nil)
                    }

                    ToolbarItem(placement: .principal) {
                        Image("ComingleLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 20, alignment: .center)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(
                            destination: {
                                SettingsView(appState: appState)
                            },
                            label: {
                                if let keypair = appState.keypair {
                                    ProfilePictureView(publicKeyHex: keypair.publicKey.hex)
                                } else {
                                    ImageOverlayView(imageSystemName: "lock.fill", overlayBackgroundColor: .accent) {
                                        if let publicKey = appState.publicKey {
                                            ProfilePictureView(publicKeyHex: publicKey.hex)
                                        } else {
                                            GuestProfilePictureView()
                                                .foregroundColor(.primary)
                                        }
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder func addEventConfirmationDialogAction() -> some View {
        NavigationLink(
            destination: {
                CreateOrModifyEventView(appState: appState)
            },
            label: {
                Text("Create Event")
            }
        )

        // Comment out calendar creation for now while it's not ready yet.
//        NavigationLink(
//            destination: {
//                CreateOrModifyCalendarView(appState: appState)
//            },
//            label: {
//                Text("Create Calendar")
//            }
//        )
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: HomeTabs

    let isSignedIn: Bool
    let onTapAction: () -> Void

    var body: some View {
        HStack {
            CustomTabBarItem(iconName: "house.fill", title: .localizable.home, tab: HomeTabs.events, selectedTab: $selectedTab, onTapAction: onTapAction)

            CustomTabBarItem(iconName: "calendar", title: .localizable.calendars, tab: HomeTabs.calendars, selectedTab: $selectedTab, onTapAction: onTapAction)
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
        .contentShape(Rectangle())
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
