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

struct EventListView: View, MetadataCoding {

    @State var eventListType: EventListType
    @EnvironmentObject var appState: AppState
    @State private var timeTabFilter: TimeTabs = .upcoming
    @State private var showAllEvents: Bool = false
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var isProfilesSectionExpanded: Bool = false
    @State private var isCalendarsSectionExpanded: Bool = false

    var body: some View {
        ScrollViewReader { scrollViewProxy in
            if eventListType == .all {
                listView(scrollViewProxy: scrollViewProxy)
                    .searchable(text: $searchViewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: String(localized: .localizable.generalSearch))
            } else {
                listView(scrollViewProxy: scrollViewProxy)
            }
        }
    }

    private func listView(scrollViewProxy: ScrollViewProxy) -> some View {
        VStack {
            CustomSegmentedPicker(selectedTimeTab: $timeTabFilter) {
                withAnimation {
                    scrollViewProxy.scrollTo("event-list-view-top")
                }
            }
            .padding([.leading, .trailing], 16)

            if eventListType == .all && appState.publicKey != nil {
                Button(action: {
                    showAllEvents.toggle()
                }, label: {
                    Image(systemName: "figure.stand.line.dotted.figure.stand")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30)
                        .foregroundStyle(showAllEvents ? .secondary : .primary)
                })
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding([.leading, .trailing], 16)
            }

            List {
                if let searchText = searchViewModel.debouncedSearchText.trimmedOrNilIfEmpty {
                    // Search by npub.
                    if eventListType == .all {
                        if let authorPublicKey = PublicKey(npub: searchText) {
                            Section(
                                content: {
                                    NavigationLink(destination: ProfileView(publicKeyHex: authorPublicKey.hex)) {
                                        ProfilePictureAndNameView(publicKeyHex: authorPublicKey.hex)
                                    }
                                },
                                header: {
                                    Text(.localizable.profiles)
                                }
                            )
                        } else if let metadata = try? decodedMetadata(from: searchText), let kind = metadata.kind, kind == EventKind.calendar.rawValue, let pubkey = metadata.pubkey, let publicKey = PublicKey(hex: pubkey) {
                            // Search by naddr.
                            if let identifier = metadata.identifier,
                               let eventCoordinates = try? EventCoordinates(kind: EventKind(rawValue: Int(kind)), pubkey: publicKey, identifier: identifier),
                               let calendarListEvent = appState.calendarListEvents[eventCoordinates.tag.value] {
                                Section(
                                    content: {
                                        NavigationLink(destination: CalendarListEventView(calendarListEventCoordinates: eventCoordinates.tag.value)) {
                                            HStack {
                                                calendarTitleAndProfileView(calendarListEvent)

                                                if let imageURL = calendarListEvent.imageURL {
                                                    imageView(imageURL)
                                                }
                                            }
                                        }
                                    },
                                    header: {
                                        Text(.localizable.calendars)
                                    }
                                )
                            }
                        } else {
                            let metadataSearchResults = appState.pubkeyTrie
                                .find(key: searchText.localizedLowercase)
                                .sorted(using: PublicKeySortComparator(order: .forward, appState: appState))
                            if !metadataSearchResults.isEmpty {
                                Section {
                                    DisclosureGroup(
                                        isExpanded: $isProfilesSectionExpanded,
                                        content: {
                                            ForEach(metadataSearchResults, id: \.self) { pubkey in
                                                NavigationLink(destination: ProfileView(publicKeyHex: pubkey)) {
                                                    ProfilePictureAndNameView(publicKeyHex: pubkey)
                                                }
                                            }
                                        },
                                        label: {
                                            Text(.localizable.profilesCount(metadataSearchResults.count))
                                        }
                                    )
                                }
                            }

                            let calendarsSearchResults = appState.calendarsTrie.find(key: searchText.localizedLowercase)
                            if !calendarsSearchResults.isEmpty {
                                Section {
                                    DisclosureGroup(
                                        isExpanded: $isCalendarsSectionExpanded,
                                        content: {
                                            let sortedCalendars = calendarsSearchResults
                                                .compactMap { appState.calendarListEvents[$0] }
                                                .filter { !$0.calendarEventCoordinateList.isEmpty }
                                                .sorted(using: CalendarListEventSortComparator(order: .forward, appState: appState))
                                            ForEach(sortedCalendars, id: \.self) { calendarListEvent in
                                                if let coordinates = calendarListEvent.replaceableEventCoordinates()?.tag.value {
                                                    NavigationLink(destination: CalendarListEventView(calendarListEventCoordinates: coordinates)) {
                                                        HStack {
                                                            calendarTitleAndProfileView(calendarListEvent)

                                                            if let imageURL = calendarListEvent.imageURL {
                                                                imageView(imageURL)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        },
                                        label: {
                                            Text(.localizable.calendarsCount(calendarsSearchResults.count))
                                        }
                                    )
                                }
                            }
                        }
                    }
                }

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

                                            if !event.participants.isEmpty {
                                                Divider()
                                                HStack {
                                                    CondensedProfilePicturesView(pubkeys: event.participants.sorted(using: CalendarEventParticipantSortComparator(order: .forward, appState: appState)).compactMap { $0.pubkey?.hex }, maxPictures: 5)
                                                    Text(.localizable.numInvited(event.participants.count))
                                                        .font(.subheadline)
                                                }
                                            }

                                            if let eventCoordinates = event.replaceableEventCoordinates()?.tag.value, let rsvps = appState.calendarEventsToRsvps[eventCoordinates] {
                                                Divider()

                                                HStack {
                                                    CondensedProfilePicturesView(pubkeys: rsvps.map { $0.pubkey }.sorted(using: PublicKeySortComparator(order: .forward, appState: appState)), maxPictures: 5)

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

                                            if let summary = event.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                                                Divider()

                                                Text(summary)
                                                    .font(.subheadline)
                                            }
                                        }

                                        if let calendarEventImageURL = event.imageURL {
                                            imageView(calendarEventImageURL)
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
        .refreshable {
            appState.refresh(hardRefresh: true)
        }
    }

    func calendarTitleAndProfileView(_ calendarListEvent: CalendarListEvent) -> some View {
        VStack(alignment: .leading) {
            Text(calendarListEvent.title?.trimmedOrNilIfEmpty ?? calendarListEvent.firstValueForRawTagName("name")?.trimmedOrNilIfEmpty ?? String(localized: .localizable.noCalendarName))
                .font(.headline)

            Divider()

            ProfilePictureAndNameView(publicKeyHex: calendarListEvent.pubkey)
        }
    }

    func imageView(_ imageURL: URL) -> some View {
        KFImage.url(imageURL)
            .resizable()
            .placeholder { ProgressView() }
            .scaledToFit()
            .frame(maxWidth: 100, maxHeight: 200)
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
        if eventListType == .all, let searchText = searchViewModel.debouncedSearchText.trimmedOrNilIfEmpty {
            // Search by npub.
            if let authorPublicKey = PublicKey(npub: searchText) {
                switch timeTabFilter {
                case .upcoming:
                    return appState.upcomingProfileEvents(authorPublicKey.hex)
                case .past:
                    return appState.pastProfileEvents(authorPublicKey.hex)
                }
            }
            if let metadata = try? decodedMetadata(from: searchText), let kind = metadata.kind, let pubkey = metadata.pubkey, let publicKey = PublicKey(hex: pubkey) {
                if kind == EventKind.timeBasedCalendarEvent.rawValue {
                    // Search by naddr.
                    if let identifier = metadata.identifier,
                       let eventCoordinates = try? EventCoordinates(kind: EventKind(rawValue: Int(kind)), pubkey: publicKey, identifier: identifier),
                       let timeBasedCalendarEvent = appState.timeBasedCalendarEvents[eventCoordinates.tag.value] {
                        if timeTabFilter == .upcoming && !timeBasedCalendarEvent.isUpcoming {
                            self.timeTabFilter = .past
                        } else if timeTabFilter == .past && !timeBasedCalendarEvent.isPast {
                            self.timeTabFilter = .upcoming
                        }
                        return [timeBasedCalendarEvent]
                        // Search by nevent.
                    } else if let eventId = metadata.eventId {
                        let results = Set(appState.eventsTrie.find(key: eventId))
                        let events = appState.timeBasedCalendarEvents.filter { results.contains($0.key) }.map { $0.value }
                        switch timeTabFilter {
                        case .upcoming:
                            return appState.upcomingEvents(events)
                        case .past:
                            return appState.pastEvents(events)
                        }
                    }
                } else if kind == EventKind.calendar.rawValue,
                          let identifier = metadata.identifier,
                          let coordinates = try? EventCoordinates(kind: EventKind(rawValue: Int(kind)), pubkey: publicKey, identifier: identifier) {
                    let coordinatesString = coordinates.tag.value
                    switch timeTabFilter {
                    case .upcoming:
                        return appState.upcomingEventsOnCalendarList(coordinatesString)
                    case .past:
                        return appState.pastEventsOnCalendarList(coordinatesString)
                    }
                }
            }

            // Search by event tags and content.
            let results = appState.eventsTrie.find(key: searchText.localizedLowercase)
            let events = appState.timeBasedCalendarEvents.filter { results.contains($0.key) }.map { $0.value }
            switch timeTabFilter {
            case .upcoming:
                return appState.upcomingEvents(events)
            case .past:
                return appState.pastEvents(events)
            }
        }

        if !showAllEvents && eventListType == .all && appState.publicKey != nil {
            switch timeTabFilter {
            case .upcoming:
                return appState.upcomingFollowedEvents
            case .past:
                return appState.pastFollowedEvents
            }
        }

        let events = switch eventListType {
        case .all:
            switch timeTabFilter {
            case .upcoming:
                appState.allUpcomingEvents
            case .past:
                appState.allPastEvents
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

        return events
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
