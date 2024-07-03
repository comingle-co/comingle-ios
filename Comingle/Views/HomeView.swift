//
//  HomeView.swift
//  Comingle
//
//  Created by Terry Yiu on 6/22/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct HomeView: View {

    @EnvironmentObject var appState: AppState

    @State private var upcomingEventsFilter: UpcomingEventsFilter = .going
    @State private var followingFilter: FollowingFilter = .upcoming

    private let dateFormatterCurrentYear = DateFormatter()
    private let dateFormatterDifferentYear = DateFormatter()

    private let dateComponentsFormatter = DateComponentsFormatter()

    init() {
        dateFormatterCurrentYear.setLocalizedDateFormatFromTemplate("EdMMMhmmz")
        dateFormatterDifferentYear.setLocalizedDateFormatFromTemplate("EdMMMyyyyhmmz")

        dateComponentsFormatter.allowedUnits = [.year, .day, .hour, .minute]
        dateComponentsFormatter.unitsStyle = .full
    }

    var body: some View {
        VStack {
//            Section {
//                Picker(selection: $upcomingEventsFilter, label: Text(.localizable.upcomingEvents)) {
//                    ForEach(UpcomingEventsFilter.allCases, id: \.self) { filter in
//                        Text(filter.localizedStringResource)
//                            .tag(filter)
//                    }
//                }
//                .pickerStyle(.segmented)
//            } header: {
//                Text(.localizable.upcomingEvents)
//                    .font(.title)
//            }
            Picker(selection: $followingFilter, label: Text(.localizable.following)) {
                ForEach(FollowingFilter.allCases, id: \.self) { filter in
                    Text(filter.localizedStringResource)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)

            List {
                ForEach(followingEvents(followingFilter), id: \.self) { event in
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

                                        if event.participants.count > 1 {
                                            let participants = event.participants.map {
                                                if let pubkey = $0.pubkey {
                                                    appState.metadataEvents[pubkey.hex]?.resolvedName ?? pubkey.hex
                                                } else {
                                                    "No npub"
                                                }
                                            }.joined(separator: ", ")

                                            Divider()

                                            Text(participants)
                                                .font(.subheadline)
                                        } else if let firstParticipant = event.participants.first, let firstParticipantPublicKey = firstParticipant.pubkey, firstParticipantPublicKey.hex != event.pubkey {
                                            Divider()

                                            Text(appState.metadataEvents[firstParticipantPublicKey.hex]?.resolvedName ?? firstParticipantPublicKey.hex)
                                                .font(.subheadline)
                                        }

                                        let locations = event.locations.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined()

                                        if !locations.isEmpty {
                                            Divider()

                                            Text(event.locations.joined())
                                                .font(.subheadline)
                                        }

                                        if let eventIdentifier = event.identifier, let rsvps = appState.calendarEventsToRsvps[eventIdentifier] {
                                            Divider()

                                            switch followingFilter {
                                            case .past:
                                                Text(.localizable.numAttended(rsvps.count))
                                                    .font(.subheadline)
                                            case .upcoming:
                                                Text(.localizable.numGoing(rsvps.count))
                                                    .font(.subheadline)
                                            }
                                        }
                                    }

                                    if let calendarEventImage = event.references.first(where: { $0.isImage }) {
                                        KFImage.url(calendarEventImage)
                                            .resizable()
                                            .placeholder { ProgressView() }
                                            .scaledToFit()
                                            .frame(width: 100)
                                    }
                                }
                            }
                        }, header: {
                            if let startTimestamp = event.startTimestamp {
                                if startTimestamp.isInCurrentYear {
                                    Text(dateFormatterCurrentYear.string(from: startTimestamp))
                                } else {
                                    Text(dateFormatterDifferentYear.string(from: startTimestamp))
                                }
                            }

                        }
                    )
                    .padding(.vertical, 10)
                }
            }
        }
    }

    func followingEvents(_ filter: FollowingFilter) -> [TimeBasedCalendarEvent] {
        switch filter {
        case .upcoming:
            appState.upcomingFollowedEvents
        case .past:
            appState.pastFollowedEvents
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

enum FollowingFilter: CaseIterable {
    case upcoming
    case past

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .upcoming:
                .localizable.followingUpcoming
        case .past:
                .localizable.followingPast
        }
    }
}

#Preview {
    HomeView()
}
