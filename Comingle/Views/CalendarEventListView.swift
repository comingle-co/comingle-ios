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

    @State var calendarEventListType: CalendarEventListType
    @EnvironmentObject var appState: AppState
    @State private var timeTabFilter: TimeTabs = .upcoming

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
                let filteredEvents = events(timeTabFilter)
                if filteredEvents.isEmpty {
                    Text(.localizable.noEvents)
                } else {
                    ForEach(filteredEvents, id: \.self) { event in
                        Section(
                            content: {
                                NavigationLink(destination: SessionView(session: event, calendar: Calendar.current)) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(verbatim: event.title ?? event.firstValueForRawTagName("name") ?? "Unnamed Event")
                                                .font(.headline)

                                            Divider()

                                            ProfilePictureAndNameView(publicKeyHex: event.pubkey)

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
            .refreshable {
                appState.refresh()
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

    func events(_ timeTabFilter: TimeTabs) -> [TimeBasedCalendarEvent] {
        switch calendarEventListType {
        case .all:
            switch timeTabFilter {
            case .upcoming:
                appState.allUpcomingEvents
            case .past:
                appState.allPastEvents
            }
        case .followed:
            switch timeTabFilter {
            case .upcoming:
                appState.upcomingFollowedEvents
            case .past:
                appState.pastFollowedEvents
            }
        case .profile:
            switch timeTabFilter {
            case .upcoming:
                appState.upcomingProfileEvents
            case .past:
                appState.pastProfileEvents
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

enum CalendarEventListType {
    case all
    case followed
    case profile
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

struct CalendarEventListView_Previews: PreviewProvider {

    @State static var appState = AppState()

    static var previews: some View {
        CalendarEventListView(calendarEventListType: .all)
    }
}
