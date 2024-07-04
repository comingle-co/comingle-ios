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
    static let defaultRelayURLString = "wss://relay.primal.net"

    @Published var loginMode: LoginMode = .none
    @Published var relay: Relay?
    @Published var activeTab: HomeTabs = .following

    @Published var publicKey: PublicKey?
    @Published var keypair: Keypair?

    @Published var followList: FollowListEvent?
    @Published var metadataEvents: [String: MetadataEvent] = [:]
    @Published var calendarListEvents: [String: CalendarListEvent] = [:]
    @Published var timeBasedCalendarEvents: [String: TimeBasedCalendarEvent] = [:]
    @Published var rsvps: [String: CalendarEventRSVP] = [:]
    @Published var calendarEventsToRsvps: [String: [CalendarEventRSVP]] = [:]

    init(loginMode: LoginMode = .none, relayUrlString: String? = nil, relay: Relay? = nil, publicKey: PublicKey? = nil, keypair: Keypair? = nil) {
        self.loginMode = loginMode
        self.relay = relay
        self.publicKey = publicKey
        self.keypair = keypair
    }

    private var allEvents: [TimeBasedCalendarEvent] {
        Array(timeBasedCalendarEvents.values)
    }

    var allUpcomingEvents: [TimeBasedCalendarEvent] {
        allEvents.filter {
            guard let startTimestamp = $0.startTimestamp else {
                return false
            }

            guard let endTimestamp = $0.endTimestamp else {
                return startTimestamp >= Date.now
            }

            return startTimestamp >= Date.now || endTimestamp >= Date.now
        }
        .sorted(using: TimeBasedCalendarEventSortComparator(order: .forward))
    }

    var allPastEvents: [TimeBasedCalendarEvent] {
        allEvents.filter {
            guard let startTimestamp = $0.startTimestamp else {
                return false
            }

            guard let endTimestamp = $0.endTimestamp else {
                return startTimestamp < Date.now
            }

            return endTimestamp < Date.now
        }
        .sorted(using: TimeBasedCalendarEventSortComparator(order: .reverse))
    }

    private var followedEvents: [TimeBasedCalendarEvent] {
        guard let followedPubkeys = followList?.followedPubkeys, !followedPubkeys.isEmpty else {
            return []
        }

        let followedPubkeysSet = Set(followedPubkeys)

        return timeBasedCalendarEvents.values.filter { $0.startTimestamp != nil && followedPubkeysSet.contains($0.pubkey) }
    }

    var upcomingFollowedEvents: [TimeBasedCalendarEvent] {
        followedEvents.filter {
            guard let startTimestamp = $0.startTimestamp else {
                return false
            }

            guard let endTimestamp = $0.endTimestamp else {
                return startTimestamp >= Date.now
            }

            return startTimestamp >= Date.now || endTimestamp >= Date.now
        }
        .sorted(using: TimeBasedCalendarEventSortComparator(order: .forward))
    }

    var pastFollowedEvents: [TimeBasedCalendarEvent] {
        followedEvents.filter {
            guard let startTimestamp = $0.startTimestamp else {
                return false
            }

            guard let endTimestamp = $0.endTimestamp else {
                return startTimestamp < Date.now
            }

            return endTimestamp < Date.now
        }
        .sorted(using: TimeBasedCalendarEventSortComparator(order: .reverse))
    }
}

extension AppState: RelayDelegate {

    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        if state == .connected {
            if let publicKey {
                guard let bootstrapFilter = Filter(
                    authors: [publicKey.hex],
                    kinds: [EventKind.followList.rawValue, EventKind.timeBasedCalendarEvent.rawValue, EventKind.dateBasedCalendarEvent.rawValue, EventKind.calendarEventRSVP.rawValue, EventKind.calendar.rawValue]
                ) else {
                    print("Unable to create the boostrap filter.")
                    return
                }

                do {
                    try relay.subscribe(with: bootstrapFilter)
                } catch {
                    print("Could not subscribe to relay with the boostrap filter.")
                }
            }

            guard let calendarFilter = Filter(
                kinds: [EventKind.calendar.rawValue, EventKind.timeBasedCalendarEvent.rawValue]
            ) else {
                print("Unable to create the calendar filter.")
                return
            }

            do {
                try relay.subscribe(with: calendarFilter)
            } catch {
                print("Could not subscribe to relay with the calendar filter.")
            }
        }
    }

    private func didReceiveFollowListEvent(_ followListEvent: FollowListEvent, forRelay relay: Relay) {
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
    }

    private func didReceiveMetadataEvent(_ metadataEvent: MetadataEvent, forRelay relay: Relay) {
        if let existingMetadataEvent = self.metadataEvents[metadataEvent.pubkey] {
            if existingMetadataEvent.createdAt < metadataEvent.createdAt {
                self.metadataEvents[metadataEvent.pubkey] = metadataEvent
            }
        } else {
            self.metadataEvents[metadataEvent.pubkey] = metadataEvent
        }
    }

    private func didReceiveCalendarListEvent(_ calendarListEvent: CalendarListEvent, forRelay relay: Relay) {
        guard let identifier = calendarListEvent.identifier else {
            return
        }

        // TODO(tyiu) validate signatures of events
        // TODO(tyiu) use event coordinates instead of just the identifier so that people can't overwrite others' events
        if let existingCalendarList = self.calendarListEvents[identifier] {
            if existingCalendarList.createdAt < calendarListEvent.createdAt {
                calendarListEvents[identifier] = calendarListEvent
            }
        } else {
            calendarListEvents[identifier] = calendarListEvent
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
    }

    private func didReceiveTimeBasedCalendarEvent(_ timeBasedCalendarEvent: TimeBasedCalendarEvent, forRelay relay: Relay) {
        guard let identifier = timeBasedCalendarEvent.identifier,
              let startTimestamp = timeBasedCalendarEvent.startTimestamp,
              startTimestamp <= timeBasedCalendarEvent.endTimestamp ?? startTimestamp,
              startTimestamp.timeIntervalSince1970 > 0 else {
            return
        }

        // TODO(tyiu) validate signatures of events
        // TODO(tyiu) use event coordinates instead of just the identifier so that people can't overwrite others' events
        if let existingEvent = self.timeBasedCalendarEvents[identifier] {
            if existingEvent.createdAt < timeBasedCalendarEvent.createdAt {
                timeBasedCalendarEvents[identifier] = timeBasedCalendarEvent
            }
        } else {
            timeBasedCalendarEvents[identifier] = timeBasedCalendarEvent
        }

        if self.metadataEvents[timeBasedCalendarEvent.pubkey] == nil {
            guard let metadataFilter = Filter(
                authors: [timeBasedCalendarEvent.pubkey],
                kinds: [EventKind.metadata.rawValue]
            ) else {
                print("Unable to create metadata filter authored by calendar event authors.")
                return
            }

            do {
                try relay.subscribe(with: metadataFilter)
            } catch {
                print("Could not subscribe to relay with metadata filter.")
            }
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
    }

    private func didReceiveCalendarEventRSVP(_ rsvp: CalendarEventRSVP, forRelay relay: Relay) {
        guard let identifier = rsvp.identifier else {
            return
        }

        // TODO(tyiu) validate signatures of events
        // TODO(tyiu) use event coordinates instead of just the identifier so that people can't overwrite others' events
        if let existingRsvp = self.rsvps[identifier] {
            if existingRsvp.createdAt < rsvp.createdAt {
                rsvps[identifier] = rsvp

                if let calendarEventIdentifier = rsvp.calendarEventCoordinates?.identifier {
                    if let rsvpsForCalendarEvent = calendarEventsToRsvps[calendarEventIdentifier] {
                        calendarEventsToRsvps[calendarEventIdentifier] = rsvpsForCalendarEvent.filter { $0.identifier != identifier } + [rsvp]
                    } else {
                        calendarEventsToRsvps[calendarEventIdentifier] = [rsvp]
                    }
                }
            }
        } else {
            rsvps[identifier] = rsvp

            if let calendarEventIdentifier = rsvp.calendarEventCoordinates?.identifier {
                if let rsvpsForCalendarEvent = calendarEventsToRsvps[calendarEventIdentifier] {
                    calendarEventsToRsvps[calendarEventIdentifier] = rsvpsForCalendarEvent.filter { $0.identifier != identifier } + [rsvp]
                } else {
                    calendarEventsToRsvps[calendarEventIdentifier] = [rsvp]
                }
            }
        }

        if self.metadataEvents[rsvp.pubkey] == nil {
            guard let metadataFilter = Filter(
                authors: [rsvp.pubkey],
                kinds: [EventKind.metadata.rawValue]
            ) else {
                print("Unable to create metadata filter authored by calendar event RSVP authors.")
                return
            }

            do {
                try relay.subscribe(with: metadataFilter)
            } catch {
                print("Could not subscribe to relay with metadata filter.")
            }
        }
    }

    func relay(_ relay: Relay, didReceive event: RelayEvent) {
        DispatchQueue.main.async {
            let nostrEvent = event.event
            switch nostrEvent {
            case let followListEvent as FollowListEvent:
                self.didReceiveFollowListEvent(followListEvent, forRelay: relay)
            case let metadataEvent as MetadataEvent:
                self.didReceiveMetadataEvent(metadataEvent, forRelay: relay)
            case let calendarListEvent as CalendarListEvent:
                self.didReceiveCalendarListEvent(calendarListEvent, forRelay: relay)
            case let timeBasedCalendarEvent as TimeBasedCalendarEvent:
                self.didReceiveTimeBasedCalendarEvent(timeBasedCalendarEvent, forRelay: relay)
            case let rsvpEvent as CalendarEventRSVP:
                self.didReceiveCalendarEventRSVP(rsvpEvent, forRelay: relay)
            default:
                break
            }
        }
    }

    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        if case let .eose(subscriptionId) = response {
            // Live new events are not strictly needed for this app for now.
            // In the future, we could keep subscriptions open for updates.
            try? relay.closeSubscription(with: subscriptionId)
        }
    }

}

enum HomeTabs {
    case following
    case explore
}
