//
//  AppState.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import Foundation
import NostrSDK
import Combine

class AppState: ObservableObject {
    @Published var loginMode: LoginMode = .none
    @Published var relay: Relay?
    @Published var keypair: Keypair?
    @Published var followList: FollowListEvent?
    @Published var metadataEvents: [String: MetadataEvent] = [:]
    @Published var calendarListEvents: [CalendarListEvent] = []
    @Published var timeBasedCalendarEvents: [TimeBasedCalendarEvent] = []
    @Published var rsvps: [String: [CalendarEventRSVP]] = [:]

    init(loginMode: LoginMode = .none, relayUrlString: String? = nil, relay: Relay? = nil, keypair: Keypair? = nil) {
        self.loginMode = loginMode
        self.relay = relay
        self.keypair = keypair
    }
}

extension AppState: RelayDelegate {

    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        if state == .connected {
            guard let filter = Filter(
                kinds: [EventKind.followList.rawValue, EventKind.timeBasedCalendarEvent.rawValue]
            ) else {
                print("Unable to create the follow list and time-based calendar event filter.")
                return
            }

            do {
                try relay.subscribe(with: filter)
            } catch {
                print("Could not subscribe to relay with follow list filter.")
            }

//            guard let followListFilter = Filter(
//                kinds: [EventKind.followList.rawValue]
//            ) else {
//                print("Unable to create a follow list filter.")
//                return
//            }
//
//            do {
//                try relay.subscribe(with: followListFilter)
//            } catch {
//                print("Could not subscribe to relay with follow list filter.")
//            }
//
//            guard let calendarFilter = Filter(
//                kinds: [EventKind.calendar.rawValue, EventKind.timeBasedCalendarEvent.rawValue]
//            ) else {
//                print("Unable to create a time-based calendar event filter.")
//                return
//            }
//
//            do {
//                try relay.subscribe(with: calendarFilter)
//            } catch {
//                print("Could not subscribe to relay with calendar filter.")
//            }
        }
    }

    func relay(_ relay: Relay, didReceive event: RelayEvent) {
        DispatchQueue.main.async {
            let nostrEvent = event.event
            switch nostrEvent {
            case let followListEvent as FollowListEvent:
                if self.followList == nil || self.followList!.createdAt < followListEvent.createdAt {
                    self.followList = followListEvent

                    let newPubkeys = Set(followListEvent.followedPubkeys).subtracting(Set(self.metadataEvents.keys))

                    guard !newPubkeys.isEmpty else {
                        return
                    }

                    guard let metadataFilter = Filter(
                        authors: Array(newPubkeys),
                        kinds: [EventKind.metadata.rawValue]
                    ) else {
                        print("Unable to create a metadata filter.")
                        return
                    }

                    do {
                        try relay.subscribe(with: metadataFilter)
                    } catch {
                        print("Could not subscribe to relay with metadata filter.")
                    }
                }
            case let metadataEvent as MetadataEvent:
                if let existingMetadataEvent = self.metadataEvents[metadataEvent.pubkey] {
                    if existingMetadataEvent.createdAt < metadataEvent.createdAt {
                        self.metadataEvents[metadataEvent.pubkey] = metadataEvent
                    }
                } else {
                    self.metadataEvents[metadataEvent.pubkey] = metadataEvent
                }
            case let calendarListEvent as CalendarListEvent:
                if !self.calendarListEvents.contains(where: { $0.id == calendarListEvent.id }) {
                    self.calendarListEvents.insert(calendarListEvent, at: 0)
                }

                if self.metadataEvents[calendarListEvent.pubkey] == nil {
                    guard let metadataFilter = Filter(
                        authors: [calendarListEvent.pubkey],
                        kinds: [EventKind.metadata.rawValue]
                    ) else {
                        print("Unable to create metadata filter authored by calendar list event authors.")
                        return
                    }

                    do {
                        try relay.subscribe(with: metadataFilter)
                    } catch {
                        print("Could not subscribe to relay with metadata filter.")
                    }
                }
            case let timeBasedCalendarEvent as TimeBasedCalendarEvent:
                if !self.timeBasedCalendarEvents.contains(where: { $0.id == timeBasedCalendarEvent.id }) {
                    self.timeBasedCalendarEvents.insert(timeBasedCalendarEvent, at: 0)
                }

                guard let metadataFilter = Filter(
                    authors: [timeBasedCalendarEvent.pubkey],
                    kinds: [EventKind.metadata.rawValue]
                ) else {
                    print("Unable to create metadata filter authored by time-based calendar event authors.")
                    return
                }

                do {
                    try relay.subscribe(with: metadataFilter)
                } catch {
                    print("Could not subscribe to relay with metadata filter.")
                }

                guard let rsvpFilter = Filter(
                    kinds: [EventKind.calendarEventRSVP.rawValue],
                    tags: ["a": ["\(EventKind.timeBasedCalendarEvent.rawValue):\(timeBasedCalendarEvent.pubkey):\(timeBasedCalendarEvent.identifier ?? "")"]]
                ) else {
                    print("Unable to create calendar event RSVP filter.")
                    return
                }

                do {
                    try relay.subscribe(with: rsvpFilter)
                } catch {
                    print("Could not subscribe to relay with calendar event RSVP filter.")
                }
//            case let rsvpEvent as CalendarEventRSVP:
//                guard let calendarEventCoordinates = rsvpEvent.calendarEventCoordinates?.identifier, self.rsvps[calendarEventCoordinates] == nil else {
//                    return
//                }
//
//                self.rsvps[calendarEventCoordinates]?.append(rsvpEvent)
            default:
                break
            }
        }
    }

}
