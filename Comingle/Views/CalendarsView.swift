//
//  CalendarsView.swift
//  Comingle
//
//  Created by Terry Yiu on 8/16/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct CalendarsView: View {

    @EnvironmentObject var appState: AppState

    private var calendarListEvents: [CalendarListEvent] {
        let comparator = CalendarListEventSortComparator(order: .forward, appState: appState)
        return appState.calendarListEvents.values
            .filter { !$0.calendarEventCoordinateList.isEmpty }
            .sorted(using: comparator)
    }

    func imageView(_ imageURL: URL) -> some View {
        KFImage.url(imageURL)
            .resizable()
            .placeholder { ProgressView() }
            .scaledToFit()
            .frame(maxWidth: 100, maxHeight: 200)
    }

    func titleAndProfileView(_ calendarListEvent: CalendarListEvent) -> some View {
        VStack(alignment: .leading) {
            Text(calendarListEvent.title?.trimmedOrNilIfEmpty ?? calendarListEvent.firstValueForRawTagName("name")?.trimmedOrNilIfEmpty ?? String(localized: .localizable.noCalendarName))
                .font(.headline)

            Divider()

            ProfilePictureAndNameView(publicKeyHex: calendarListEvent.pubkey)
        }
    }

    var body: some View {
        List {
            ForEach(calendarListEvents, id: \.self) { calendarListEvent in
                Section(
                    content: {
                        NavigationLink(destination: {
                            if let coordinates = calendarListEvent.replaceableEventCoordinates()?.tag.value {
                                CalendarListEventView(calendarListEventCoordinates: coordinates)
                            }
                        }, label: {
                            HStack {
                                titleAndProfileView(calendarListEvent)
                                if let imageURL = calendarListEvent.imageURL {
                                    imageView(imageURL)
                                }
                            }
                        })
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

//#Preview {
//    CalendarsView()
//}
