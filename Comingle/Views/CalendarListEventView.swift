//
//  CalendarListEventView.swift
//  Comingle
//
//  Created by Terry Yiu on 8/16/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct CalendarListEventView: View {

    @EnvironmentObject private var appState: AppState

    @State var calendarListEventCoordinates: String

    @State private var isDescriptionExpanded: Bool = false

    private let maxDescriptionLength = 140

    private var calendarListEvent: CalendarListEvent? {
        appState.calendarListEvents[calendarListEventCoordinates]
    }

    private var naddr: String? {
        if let calendarListEvent {
            let relays = appState.persistentNostrEvent(calendarListEvent.id)?.relays ?? []
            return try? calendarListEvent.shareableEventCoordinates(relayURLStrings: relays.map { $0.absoluteString })
        }
        return nil
    }

    private var calendarURL: URL? {
        if let naddr, let njumpURL = URL(string: "https://njump.me/\(naddr)"), UIApplication.shared.canOpenURL(njumpURL) {
            return njumpURL
        }
        return nil
    }

    var body: some View {
        if let calendarListEvent {
            VStack {
                if let imageURL = calendarListEvent.imageURL {
                    KFImage.url(imageURL)
                        .resizable()
                        .placeholder { ProgressView() }
                        .scaledToFit()
                        .frame(width: 40)
                        .clipShape(.circle)
                }

                Text(calendarListEvent.title ?? calendarListEvent.firstValueForRawTagName("name") ?? String(localized: .localizable.noCalendarName))
                    .font(.headline)

                NavigationLink(destination: ProfileView(publicKeyHex: calendarListEvent.pubkey)) {
                    ProfilePictureAndNameView(publicKeyHex: calendarListEvent.pubkey)
                }

                if let description = calendarListEvent.content.trimmedOrNilIfEmpty {
                    VStack(alignment: .leading) {
                        if isDescriptionExpanded || description.count <= maxDescriptionLength {
                            Text(.init(description))
                                .font(.subheadline)
                        } else {
                            Text(.init(description.prefix(maxDescriptionLength) + "..."))
                                .font(.subheadline)
                        }

                        if description.count > maxDescriptionLength {
                            Button(action: {
                                isDescriptionExpanded.toggle()
                            }, label: {
                                if isDescriptionExpanded {
                                    Text(.localizable.showLess)
                                        .font(.subheadline)
                                } else {
                                    Text(.localizable.showMore)
                                        .font(.subheadline)
                                }
                            })
                        }
                    }
                }

                EventListView(eventListType: .calendar(calendarListEventCoordinates))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button(action: {
                            UIPasteboard.general.string = naddr
                        }, label: {
                            Text(.localizable.copyCalendarID)
                        })

                        if let calendarURL {
                            Button(action: {
                                UIPasteboard.general.string = calendarURL.absoluteString
                            }, label: {
                                Text(.localizable.copyCalendarURL)
                            })
                        }
                    } label: {
                        Label(.localizable.menu, systemImage: "ellipsis.circle")
                    }
                }
            }
        } else {
            EmptyView()
        }
    }
}

//#Preview {
//    CalendarListEventView()
//}
