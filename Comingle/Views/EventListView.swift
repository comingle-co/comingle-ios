//
//  EventListView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/3/24.
//

import Kingfisher
import NostrSDK
import SwiftData
import SwiftUI

struct EventListView: View {

    @State var eventListType: EventListType
    @EnvironmentObject var appState: AppState
    @State private var timeTabFilter: TimeTabs = .upcoming

    var body: some View {
        ScrollViewReader { scrollViewProxy in
            VStack {
                CustomSegmentedPicker(selectedTimeTab: $timeTabFilter) {
                    withAnimation {
                        scrollViewProxy.scrollTo("event-list-view-top")
                    }
                }

                ZStack {
                    List {
                        let filteredEvents = events(timeTabFilter)
                        if filteredEvents.isEmpty {
                            Text(.localizable.noEvents)
                        } else {
                            EmptyView().id("event-list-view-top")

                            ForEach(filteredEvents, id: \.self) { event in
                                Section(
                                    content: {
                                        NavigationLink(destination: EventView(appState: appState, event: event)) {
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

                                                    if let summary = event.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                                                        Divider()

                                                        Text(summary)
                                                            .font(.subheadline)
                                                    }
                                                }

                                                if let calendarEventImageURL = event.imageURL {
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
            }
            .refreshable {
                appState.refresh(hardRefresh: true)
            }
        }
    }

    private func resolveTimeZone(_ timeZone: TimeZone?) -> TimeZone {
        guard let timeZone else {
            return Calendar.autoupdatingCurrent.timeZone
        }

        switch appState.appearanceSettings?.timeZonePreference {
        case .event:
            return timeZone
        case .system, .none:
            return Calendar.autoupdatingCurrent.timeZone
        }
    }

    private func format(date: Date, timeZone: TimeZone?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = resolveTimeZone(timeZone)

        if Calendar.autoupdatingCurrent.isDate(date, equalTo: Date.now, toGranularity: .year) {
            dateFormatter.setLocalizedDateFormatFromTemplate("EdMMMhmmz")
            return dateFormatter.string(from: date)
        } else {
            dateFormatter.setLocalizedDateFormatFromTemplate("EdMMMyyyyhmmz")
            return dateFormatter.string(from: date)
        }
    }

    func events(_ timeTabFilter: TimeTabs) -> [TimeBasedCalendarEvent] {
        switch eventListType {
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
        case .profile(let publicKeyHex):
            switch timeTabFilter {
            case .upcoming:
                appState.upcomingProfileEvents(publicKeyHex)
            case .past:
                appState.pastProfileEvents(publicKeyHex)
            }
        case .calendar(let calendarCoordinates):
            switch timeTabFilter {
            case .upcoming:
                appState.upcomingEventsOnCalendarList(calendarCoordinates)
            case .past:
                appState.pastEventsOnCalendarList(calendarCoordinates)
            }
        }
    }
}

struct CustomSegmentedPicker: View {
    @Binding var selectedTimeTab: TimeTabs

    let onTapAction: () -> Void

    var body: some View {
        HStack {
            ForEach(TimeTabs.allCases, id: \.self) { timeTab in
                CustomSegmentedPickerItem(title: timeTab.localizedStringResource, timeTab: timeTab, selectedTimeTab: $selectedTimeTab, onTapAction: onTapAction)
            }
        }
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

struct CustomSegmentedPickerItem: View {
    let title: LocalizedStringResource
    let timeTab: TimeTabs
    @Binding var selectedTimeTab: TimeTabs

    let onTapAction: () -> Void

    var body: some View {
        Text(title)
            .font(.subheadline)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(selectedTimeTab == timeTab ? .accent : Color.clear)
            .foregroundColor(selectedTimeTab == timeTab ? .white : .secondary)
            .cornerRadius(8)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedTimeTab = timeTab
                onTapAction()
            }
    }
}

extension Date {
    var isInCurrentYear: Bool {
        let calendar = Calendar.autoupdatingCurrent
        return calendar.component(.year, from: .now) == calendar.component(.year, from: self)
    }
}

enum EventListType: Equatable {
    case all
    case followed
    case profile(String)
    case calendar(String)
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

//struct EventListView_Previews: PreviewProvider {
//
//    @State static var appState = AppState()
//
//    static var previews: some View {
//        EventListView(eventListType: .all)
//    }
//}
