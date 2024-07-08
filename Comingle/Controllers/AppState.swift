//
//  AppState.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import Foundation
import NostrSDK
import Combine
import SwiftData

class AppState: ObservableObject {
    static let defaultRelayURLString = "wss://relay.primal.net"

    @Published var loginMode: LoginMode = .none
    @Published var relayPool: RelayPool = RelayPool(relays: [])
    @Published var activeTab: HomeTabs = .following

    @Published var keypair: Keypair?

    @Published var followListEvents: [String: FollowListEvent] = [:]
    @Published var metadataEvents: [String: MetadataEvent] = [:]
    @Published var calendarListEvents: [String: CalendarListEvent] = [:]
    @Published var timeBasedCalendarEvents: [String: TimeBasedCalendarEvent] = [:]
    @Published var rsvps: [String: CalendarEventRSVP] = [:]
    @Published var calendarEventsToRsvps: [String: [CalendarEventRSVP]] = [:]

    @Published var appSettings: AppSettings?

    init(loginMode: LoginMode = .none, keypair: Keypair? = nil) {
        self.loginMode = loginMode
        self.keypair = keypair
    }

    var publicKey: PublicKey? {
        if let appSettings, let publicKeyHex = appSettings.activeProfile?.publicKeyHex {
            PublicKey(hex: publicKeyHex)
        } else {
            nil
        }
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

    private var followedRSVPCalendarEventCoordinates: Set<String> {
        guard let publicKeyHex = publicKey?.hex,
              let followedPubkeys = followListEvents[publicKeyHex]?.followedPubkeys,
              !followedPubkeys.isEmpty else {
            return []
        }

        let followedPubkeysSet = Set(followedPubkeys)

        return Set(
            rsvps.values
                .filter { followedPubkeysSet.contains($0.pubkey) }
                .compactMap { $0.calendarEventCoordinates?.tag.value })
    }

    /// Events that were created or RSVP'd by follow list.
    private var followedEvents: [TimeBasedCalendarEvent] {
        guard let publicKeyHex = publicKey?.hex,
              let followedPubkeys = followListEvents[publicKeyHex]?.followedPubkeys,
              !followedPubkeys.isEmpty else {
            return []
        }

        let followedPubkeysSet = Set(followedPubkeys)
        let followedRSVPCalendarEventCoordinates = followedRSVPCalendarEventCoordinates

        return timeBasedCalendarEvents.values.filter {
            $0.startTimestamp != nil
            && (followedPubkeysSet.contains($0.pubkey)
                || followedRSVPCalendarEventCoordinates.contains($0.pubkey)
                || $0.participants.contains(where: {
                guard let pubkey = $0.pubkey else {
                    return false
                }
                return followedPubkeysSet.contains(pubkey.hex)
            }))
        }
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

extension AppState: EventVerifying, RelayDelegate {

    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        if state == .connected {
            refresh(relay: relay)
        }
    }

    func pullMissingMetadata(_ pubkeys: [String]) {
        let pubkeysToFetchMetadata = Set(pubkeys).filter { self.metadataEvents[$0] == nil }
        if !pubkeysToFetchMetadata.isEmpty {
            guard let metadataFilter = Filter(
                authors: Array(pubkeysToFetchMetadata),
                kinds: [EventKind.metadata.rawValue]
            ) else {
                print("Unable to create metadata filter for \(pubkeysToFetchMetadata).")
                return
            }

            _ = relayPool.subscribe(with: metadataFilter)
        }
    }

    func refresh(publicKeyHex: String? = nil, relay: Relay? = nil) {
        guard relay == nil || relay?.state == .connected else {
            return
        }

        let authors: [String]
        if let publicKeyHex {
            authors = [publicKeyHex]
        } else if let publicKeys = appSettings?.profiles.compactMap({ $0.publicKeyHex }) {
            authors = publicKeys
        } else {
            authors = []
        }

        if !authors.isEmpty {
            guard let bootstrapFilter = Filter(
                authors: authors,
                kinds: [EventKind.metadata.rawValue, EventKind.followList.rawValue, EventKind.timeBasedCalendarEvent.rawValue, EventKind.dateBasedCalendarEvent.rawValue, EventKind.calendarEventRSVP.rawValue, EventKind.calendar.rawValue]
            ) else {
                print("Unable to create the boostrap filter.")
                return
            }

            if let relay {
                do {
                    try relay.subscribe(with: bootstrapFilter)
                } catch {
                    print("Could not subscribe to relay with the boostrap filter.")
                }
            } else {
                _ = relayPool.subscribe(with: bootstrapFilter)
            }
        }

        guard let calendarFilter = Filter(
            kinds: [EventKind.calendar.rawValue, EventKind.timeBasedCalendarEvent.rawValue]
        ) else {
            print("Unable to create the calendar filter.")
            return
        }

        if let relay {
            do {
                try relay.subscribe(with: calendarFilter)
            } catch {
                print("Could not subscribe to relay with the calendar filter.")
            }
        } else {
            _ = relayPool.subscribe(with: calendarFilter)
        }
    }

    private func didReceiveFollowListEvent(_ followListEvent: FollowListEvent, forRelay relay: Relay) {
        if let existingFollowList = self.followListEvents[followListEvent.pubkey] {
            if existingFollowList.createdAt < followListEvent.createdAt {
                self.followListEvents[followListEvent.pubkey] = followListEvent
            }
        } else {
            self.followListEvents[followListEvent.pubkey] = followListEvent
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
        guard let calendarListEventCoordinates = calendarListEvent.replaceableEventCoordinates()?.tag.value else {
            return
        }

        if let existingCalendarList = self.calendarListEvents[calendarListEventCoordinates] {
            if existingCalendarList.createdAt < calendarListEvent.createdAt {
                calendarListEvents[calendarListEventCoordinates] = calendarListEvent
            }
        } else {
            calendarListEvents[calendarListEventCoordinates] = calendarListEvent
        }

        pullMissingMetadata([calendarListEvent.pubkey])
    }

    private func didReceiveTimeBasedCalendarEvent(_ timeBasedCalendarEvent: TimeBasedCalendarEvent, forRelay relay: Relay) {
        guard let eventCoordinates = timeBasedCalendarEvent.replaceableEventCoordinates()?.tag.value,
              let startTimestamp = timeBasedCalendarEvent.startTimestamp,
              startTimestamp <= timeBasedCalendarEvent.endTimestamp ?? startTimestamp,
              startTimestamp.timeIntervalSince1970 > 0 else {
            return
        }

        if let existingEvent = self.timeBasedCalendarEvents[eventCoordinates] {
            if existingEvent.createdAt < timeBasedCalendarEvent.createdAt {
                timeBasedCalendarEvents[eventCoordinates] = timeBasedCalendarEvent
            }
        } else {
            timeBasedCalendarEvents[eventCoordinates] = timeBasedCalendarEvent
        }

        pullMissingMetadata([timeBasedCalendarEvent.pubkey])

        guard let replaceableEventCoordinates = timeBasedCalendarEvent.replaceableEventCoordinates() else {
            print("Unable to get replaceable event coordinates for time-based calendar event.")
            return
        }

        let replaceableEventCoordinatesTag = replaceableEventCoordinates.tag

        guard let rsvpFilter = Filter(
            kinds: [EventKind.calendarEventRSVP.rawValue],
            tags: ["a": [replaceableEventCoordinatesTag.value]])
        else {
            print("Unable to create calendar event RSVP filter.")
            return
        }

        _ = relayPool.subscribe(with: rsvpFilter)
    }

    private func didReceiveCalendarEventRSVP(_ rsvp: CalendarEventRSVP, forRelay relay: Relay) {
        guard let rsvpEventCoordinates = rsvp.replaceableEventCoordinates()?.tag.value else {
            return
        }

        if let existingRsvp = self.rsvps[rsvpEventCoordinates] {
            if existingRsvp.createdAt < rsvp.createdAt {
                rsvps[rsvpEventCoordinates] = rsvp

                if let calendarEventCoordinates = rsvp.calendarEventCoordinates?.tag.value {
                    if let rsvpsForCalendarEvent = calendarEventsToRsvps[calendarEventCoordinates] {
                        calendarEventsToRsvps[calendarEventCoordinates] = rsvpsForCalendarEvent.filter { $0.replaceableEventCoordinates()?.tag.value != rsvpEventCoordinates } + [rsvp]
                    } else {
                        calendarEventsToRsvps[calendarEventCoordinates] = [rsvp]
                    }
                }
            }
        } else {
            rsvps[rsvpEventCoordinates] = rsvp

            if let calendarEventCoordinates = rsvp.calendarEventCoordinates?.tag.value {
                if let rsvpsForCalendarEvent = calendarEventsToRsvps[calendarEventCoordinates] {
                    calendarEventsToRsvps[calendarEventCoordinates] = rsvpsForCalendarEvent.filter { $0.replaceableEventCoordinates()?.tag.value != rsvpEventCoordinates } + [rsvp]
                } else {
                    calendarEventsToRsvps[calendarEventCoordinates] = [rsvp]
                }
            }
        }

        // Optimization: do not pull metadata of people who RSVP until we actually need to look at it. Lazy load.
        // Perhaps reconsider if UX suffers because of this decision..
        // pullMissingMetadata([rsvp.pubkey])
    }

    func relay(_ relay: Relay, didReceive event: RelayEvent) {
        DispatchQueue.main.async {
            let nostrEvent = event.event

            // Verify the id and signature of the event.
            // If the verification throws an error, that means they are invalid and we should ignore the event.
            try? self.verifyEvent(nostrEvent)

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
    case profile
    case settings
}
