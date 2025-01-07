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
    @StateObject private var searchViewModel = SearchViewModel()

    private var calendarListEvents: [CalendarListEvent] {
        let calendarsSearchResults: [CalendarListEvent]

        if let searchText = searchViewModel.debouncedSearchText.trimmedOrNilIfEmpty {
            calendarsSearchResults = appState.calendarsTrie.find(key: searchText.localizedLowercase)
                .compactMap { appState.calendarListEvents[$0] }
                .filter { !$0.calendarEventCoordinateList.isEmpty }
        } else {
            calendarsSearchResults = appState.calendarListEvents.values
                .filter { !$0.calendarEventCoordinateList.isEmpty }
        }

        return calendarsSearchResults
            .sorted(using: CalendarListEventSortComparator(order: .forward, appState: appState))
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
            Text(calendarListEvent.title?.trimmedOrNilIfEmpty ?? calendarListEvent.firstValueForRawTagName("name")?.trimmedOrNilIfEmpty ?? String(localized: "No Name", comment: "Text to indicate that there is no title for the calendar."))
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
        .searchable(text: $searchViewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: String(localized: "Search for calendars", comment: "Placeholder text to prompt user to search calendars"))
    }
}

//#Preview {
//    CalendarsView()
//}
