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
        } else {
            EmptyView()
        }
    }
}

//#Preview {
//    CalendarListEventView()
//}
