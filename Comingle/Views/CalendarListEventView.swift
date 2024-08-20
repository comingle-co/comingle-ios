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

    @State private var isDescriptionExpanded: Bool = true

    private var calendarListEvent: CalendarListEvent? {
        appState.calendarListEvents[calendarListEventCoordinates]
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

                DisclosureGroup(
                    isExpanded: $isDescriptionExpanded,
                    content: {
                        if let description = calendarListEvent.content.trimmedOrNilIfEmpty {
                            ScrollView {
                                Text(.init(description))
                                    .font(.subheadline)
                            }
                        }
                    },
                    label: {
                        Text(calendarListEvent.title ?? calendarListEvent.firstValueForRawTagName("name") ?? String(localized: .localizable.noCalendarName))
                            .font(.headline)
                    }
                )

                EventListView(eventListType: .calendar(calendarListEventCoordinates))
            }
        } else {
            EmptyView()
        }
    }
}

//#Preview {
//    CalendarListEventView()
//}
