//
//  CalendarEventListView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/3/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct CalendarEventListView: View {

    @EnvironmentObject var appState: AppState

    @State private var upcomingEventsFilter: UpcomingEventsFilter = .going
    @State private var timeTabFilter: TimeTabs = .upcoming

    @State private var showAllEvents: Bool

    init(showAllEvents: Bool) {
        self.showAllEvents = showAllEvents
    }

    var body: some View {
        VStack {
            Picker(selection: $timeTabFilter, label: Text(.localizable.following)) {
                ForEach(TimeTabs.allCases, id: \.self) { filter in
                    Text(filter.localizedStringResource)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)

            List {
                ForEach(followingEvents(timeTabFilter), id: \.self) { event in
                    Section(
                        content: {
                            NavigationLink(destination: SessionView(session: event, calendar: Calendar.current).environmentObject(appState)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(verbatim: event.title ?? event.firstValueForRawTagName("name") ?? "Unnamed Event")
                                            .font(.headline)

                                        Divider()

                                        HStack {
                                            let metadataEvent = appState.metadataEvents[event.pubkey]

                                            if let pictureURL = metadataEvent?.userMetadata?.pictureURL {
                                                KFImage.url(pictureURL)
                                                    .resizable()
                                                    .placeholder { ProgressView() }
                                                    .scaledToFit()
                                                    .frame(width: 40)
                                                    .clipShape(.circle)
                                            }

                                            Text(metadataEvent?.resolvedName ?? event.pubkey)
                                                .font(.subheadline)
                                        }

                                        let locations = event.locations.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined()

                                        if !locations.isEmpty {
                                            Divider()

                                            Text(event.locations.joined())
                                                .font(.subheadline)
                                        }

                                        if let eventCoordinates = event.replaceableEventCoordinates()?.tag.value, let rsvps = appState.calendarEventsToRsvps[eventCoordinates] {
                                            Divider()

                                            switch timeTabFilter {
                                            case .past:
                                                Text(.localizable.numAttended(rsvps.count))
                                                    .font(.subheadline)
                                            case .upcoming:
                                                Text(.localizable.numGoing(rsvps.count))
                                                    .font(.subheadline)
                                            }
                                        }
                                    }

                                    if let calendarEventImage = event.firstValueForRawTagName("image"), let calendarEventImageURL = URL(string: calendarEventImage), calendarEventImageURL.isImage {
                                        KFImage.url(calendarEventImageURL)
                                            .resizable()
                                            .placeholder { ProgressView() }
                                            .scaledToFit()
                                            .frame(maxWidth: 100, maxHeight: 200)
                                    }
                                }
                            }
                        }, header: {
                            if let startTimestamp = event.startTimestamp {
                                Text(format(date: startTimestamp, timeZone: event.startTimeZone))
                            }
                        }
                    )
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private func format(date: Date, timeZone: TimeZone?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = timeZone ?? Calendar.current.timeZone

        if date.isInCurrentYear {
            dateFormatter.setLocalizedDateFormatFromTemplate("EdMMMhmmz")
            return dateFormatter.string(from: date)
        } else {
            dateFormatter.setLocalizedDateFormatFromTemplate("EdMMMyyyyhmmz")
            return dateFormatter.string(from: date)
        }
    }

    func followingEvents(_ timeTabFilter: TimeTabs) -> [TimeBasedCalendarEvent] {
        if showAllEvents {
            switch timeTabFilter {
            case .upcoming:
                appState.allUpcomingEvents
            case .past:
                appState.allPastEvents
            }
        } else {
            switch timeTabFilter {
            case .upcoming:
                appState.upcomingFollowedEvents
            case .past:
                appState.pastFollowedEvents
            }
        }
    }
}

extension URL {
    private static var imageExtensions = Set([
        "bmp",
        "gif",
        "heic",
        "heif",
        "jpeg",
        "jpg",
        "png",
        "tif",
        "tiff",
        "webp"
    ])

    var isImage: Bool {
        URL.imageExtensions.contains(self.pathExtension.lowercased())
    }
}

extension Date {
    var isInCurrentYear: Bool {
        let calendar = Calendar.current
        return calendar.component(.year, from: .now) == calendar.component(.year, from: self)
    }
}

enum UpcomingEventsFilter: CaseIterable {
    case going
    case saved

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .going:
                .localizable.going
        case .saved:
                .localizable.saved
        }
    }
}

enum TimeTabs: CaseIterable {
    case upcoming
    case past

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .upcoming:
                .localizable.upcoming
        case .past:
                .localizable.past
        }
    }
}

#Preview {
    CalendarEventListView(showAllEvents: false)
}
