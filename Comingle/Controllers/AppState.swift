//
//  AppState.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import Foundation
import NostrSDK
import SwiftData
import SwiftTrie

class AppState: ObservableObject, Hashable {
    static func == (lhs: AppState, rhs: AppState) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let defaultRelayURLString = "wss://relay.primal.net"

    let id = UUID()

    let privateKeySecureStorage = PrivateKeySecureStorage()

    let modelContext: ModelContext

    @Published var relayPool: RelayPool = RelayPool(relays: [])
    @Published var activeTab: HomeTabs = .following

    @Published var persistentNostrEvents: [String: PersistentNostrEvent] = [:]

    @Published var followListEvents: [String: FollowListEvent] = [:]
    @Published var metadataEvents: [String: MetadataEvent] = [:]
    @Published var calendarListEvents: [String: CalendarListEvent] = [:]
    @Published var timeBasedCalendarEvents: [String: TimeBasedCalendarEvent] = [:]
    @Published var rsvps: [String: CalendarEventRSVP] = [:]
    @Published var calendarEventsToRsvps: [String: [CalendarEventRSVP]] = [:]

    @Published var appSettings: AppSettings?
    @Published var profiles: [Profile] = []

    @Published var metadataTrie = Trie<MetadataEvent>()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var publicKey: PublicKey? {
        if let appSettings, let publicKeyHex = appSettings.activeProfile?.publicKeyHex {
            PublicKey(hex: publicKeyHex)
        } else {
            nil
        }
    }

    var keypair: Keypair? {
        guard let publicKey else {
            return nil
        }
        return privateKeySecureStorage.keypair(for: publicKey)
    }

    private var allEvents: [TimeBasedCalendarEvent] {
        Array(timeBasedCalendarEvents.values)
    }

    var allUpcomingEvents: [TimeBasedCalendarEvent] {
        upcomingEvents(allEvents)
    }

    var allPastEvents: [TimeBasedCalendarEvent] {
        pastEvents(allEvents)
    }

    private var followedRSVPCalendarEventCoordinates: Set<String> {
        guard let publicKeyHex = publicKey?.hex else {
            return []
        }

        let followedPubkeysSet = Set((followListEvents[publicKeyHex]?.followedPubkeys ?? []) + [publicKeyHex])

        return Set(
            rsvps.values
                .filter { followedPubkeysSet.contains($0.pubkey) }
                .compactMap { $0.calendarEventCoordinates?.tag.value })
    }

    /// Events that were created or RSVP'd by follow list.
    private var followedEvents: [TimeBasedCalendarEvent] {
        guard let publicKeyHex = publicKey?.hex else {
            return []
        }

        let followedPubkeysSet = Set((followListEvents[publicKeyHex]?.followedPubkeys ?? []) + [publicKeyHex])
        let followedRSVPCalendarEventCoordinates = followedRSVPCalendarEventCoordinates

        return timeBasedCalendarEvents.values.filter { event in
            guard let coordinates = event.replaceableEventCoordinates() else {
                return false
            }

            return event.startTimestamp != nil
            && (followedPubkeysSet.contains(event.pubkey)
                || followedRSVPCalendarEventCoordinates.contains(coordinates.tag.value)
                || event.participants.contains(where: { participant in
                guard let participantPubkey = participant.pubkey else {
                    return false
                }
                return followedPubkeysSet.contains(participantPubkey.hex)
            }))
        }
    }

    var upcomingFollowedEvents: [TimeBasedCalendarEvent] {
        upcomingEvents(followedEvents)
    }

    var pastFollowedEvents: [TimeBasedCalendarEvent] {
        pastEvents(followedEvents)
    }

    private func profileRSVPCalendarEventCoordinates(_ publicKeyHex: String) -> Set<String> {
        return Set(
            rsvps.values
                .filter { $0.pubkey == publicKeyHex }
                .compactMap { $0.calendarEventCoordinates?.tag.value })
    }

    /// Events that were created or RSVP'd by the active profile.
    private func profileEvents(_ publicKeyHex: String) -> [TimeBasedCalendarEvent] {
        let profileRSVPCalendarEventCoordinates = profileRSVPCalendarEventCoordinates

        return timeBasedCalendarEvents.values.filter { event in
            guard let coordinates = event.replaceableEventCoordinates() else {
                return false
            }

            return event.startTimestamp != nil
            && (event.pubkey == publicKeyHex
                || profileRSVPCalendarEventCoordinates(publicKeyHex).contains(coordinates.tag.value)
                || event.participants.contains(where: { participant in participant.pubkey?.hex == publicKeyHex })
            )
        }
    }

    func upcomingProfileEvents(_ publicKeyHex: String) -> [TimeBasedCalendarEvent] {
        upcomingEvents(profileEvents(publicKeyHex))
    }

    func pastProfileEvents(_ publicKeyHex: String) -> [TimeBasedCalendarEvent] {
        pastEvents(profileEvents(publicKeyHex))
    }

    private func upcomingEvents(_ events: [TimeBasedCalendarEvent]) -> [TimeBasedCalendarEvent] {
        events.filter {
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

    private func pastEvents(_ events: [TimeBasedCalendarEvent]) -> [TimeBasedCalendarEvent] {
        events.filter {
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

    func updateRelayPool() {
        let profile = appSettings?.activeProfile
        let relays = (profile?.profileSettings?.relayPoolSettings?.relaySettingsList ?? [])
            .compactMap { URL(string: $0.relayURLString) }
            .compactMap { try? Relay(url: $0) }
        let relaySet = Set(relays)

        let oldRelays = relayPool.relays.subtracting(relaySet)
        let newRelays = relaySet.subtracting(relayPool.relays)

        relayPool.delegate = self

        oldRelays.forEach {
            relayPool.remove(relay: $0)
        }
        newRelays.forEach {
            relayPool.add(relay: $0)
        }
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

    func refresh(relay: Relay? = nil) {
        guard (relay == nil && !relayPool.relays.isEmpty) || relay?.state == .connected else {
            return
        }

        let authors = profiles.compactMap({ $0.publicKeyHex })
        if !authors.isEmpty {
            guard let bootstrapFilter = Filter(
                authors: authors,
                kinds: [EventKind.metadata.rawValue, EventKind.followList.rawValue, EventKind.timeBasedCalendarEvent.rawValue, EventKind.dateBasedCalendarEvent.rawValue, EventKind.calendarEventRSVP.rawValue, EventKind.calendar.rawValue, EventKind.deletion.rawValue]
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

    private func didReceiveFollowListEvent(_ followListEvent: FollowListEvent, shouldPullMissingMetadata: Bool = false) {
        if let existingFollowList = self.followListEvents[followListEvent.pubkey] {
            if existingFollowList.createdAt < followListEvent.createdAt {
                cache(followListEvent)
            }
        } else {
            cache(followListEvent)
        }

        if shouldPullMissingMetadata {
            pullMissingMetadata(followListEvent.followedPubkeys)
        }
    }

    private func cache(_ followListEvent: FollowListEvent) {
        self.followListEvents[followListEvent.pubkey] = followListEvent
    }

    private func didReceiveMetadataEvent(_ metadataEvent: MetadataEvent) {
        if let existingMetadataEvent = self.metadataEvents[metadataEvent.pubkey] {
            if existingMetadataEvent.createdAt < metadataEvent.createdAt {
                cache(metadataEvent)
            }
        } else {
            cache(metadataEvent)
        }
    }

    private func cache(_ metadataEvent: MetadataEvent) {
        self.metadataEvents[metadataEvent.pubkey] = metadataEvent

        if let userMetadata = metadataEvent.userMetadata {
            if let name = userMetadata.name?.trimmingCharacters(in: .whitespacesAndNewlines) {
                _ = metadataTrie.insert(key: name, value: metadataEvent, options: [.includeCaseInsensitiveMatches, .includeDiacriticsInsensitiveMatches, .includeNonPrefixedMatches])
            }
            if let displayName = userMetadata.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) {
                _ = metadataTrie.insert(key: displayName, value: metadataEvent, options: [.includeCaseInsensitiveMatches, .includeDiacriticsInsensitiveMatches, .includeNonPrefixedMatches])
            }
        }

        if let publicKey = PublicKey(hex: metadataEvent.pubkey) {
            _ = metadataTrie.insert(key: publicKey.npub, value: metadataEvent, options: [.includeCaseInsensitiveMatches, .includeDiacriticsInsensitiveMatches, .includeNonPrefixedMatches])
        }
    }

    private func didReceiveCalendarListEvent(_ calendarListEvent: CalendarListEvent, shouldPullMissingMetadata: Bool = false) {
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

        if shouldPullMissingMetadata {
            pullMissingMetadata([calendarListEvent.pubkey])
        }
    }

    private func didReceiveTimeBasedCalendarEvent(_ timeBasedCalendarEvent: TimeBasedCalendarEvent, shouldPullMissingMetadata: Bool = false) {
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

        if shouldPullMissingMetadata {
            pullMissingMetadata([timeBasedCalendarEvent.pubkey])
        }

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

    func updateCalendarEventRSVP(_ rsvp: CalendarEventRSVP, rsvpEventCoordinates: String) {
        rsvps[rsvpEventCoordinates] = rsvp

        if let calendarEventCoordinates = rsvp.calendarEventCoordinates?.tag.value {
            if let rsvpsForCalendarEvent = calendarEventsToRsvps[calendarEventCoordinates] {
                // It is possible that a pubkey RSVPs multiple times to the same calendar event using different d tags.
                // Keep only the newest one.
                if rsvpsForCalendarEvent.allSatisfy({ $0.pubkey != rsvp.pubkey || $0.createdAt < rsvp.createdAt }) {
                    calendarEventsToRsvps[calendarEventCoordinates] = rsvpsForCalendarEvent.filter {
                        $0.pubkey != rsvp.pubkey
                    } + [rsvp]
                }
            } else {
                calendarEventsToRsvps[calendarEventCoordinates] = [rsvp]
            }
        }
    }

    private func didReceiveCalendarEventRSVP(_ rsvp: CalendarEventRSVP) {
        guard let rsvpEventCoordinates = rsvp.replaceableEventCoordinates()?.tag.value else {
            return
        }

        if let existingRsvp = self.rsvps[rsvpEventCoordinates] {
            if existingRsvp.createdAt < rsvp.createdAt {
                updateCalendarEventRSVP(rsvp, rsvpEventCoordinates: rsvpEventCoordinates)
            }
        } else {
            updateCalendarEventRSVP(rsvp, rsvpEventCoordinates: rsvpEventCoordinates)
        }

        // Optimization: do not pull metadata of people who RSVP until we actually need to look at it. Lazy load.
        // Perhaps reconsider if UX suffers because of this decision..
        // pullMissingMetadata([rsvp.pubkey])
    }

    private func deleteFromEventCoordinates(_ deletionEvent: DeletionEvent) {
        let deletedEventCoordinates = deletionEvent.eventCoordinates.filter {
            $0.pubkey?.hex == deletionEvent.pubkey
        }

        for deletedEventCoordinate in deletedEventCoordinates {
            switch deletedEventCoordinate.kind {
            case .calendar:
                if let calendarListEvent = calendarListEvents[deletedEventCoordinate.tag.value], calendarListEvent.createdAt <= deletionEvent.createdAt {
                    calendarListEvents.removeValue(forKey: deletedEventCoordinate.tag.value)
                    persistentNostrEvents.removeValue(forKey: calendarListEvent.id)
                }
            case .timeBasedCalendarEvent:
                if let timeBasedCalendarEvent = calendarListEvents[deletedEventCoordinate.tag.value], timeBasedCalendarEvent.createdAt <= deletionEvent.createdAt {
                    timeBasedCalendarEvents.removeValue(forKey: deletedEventCoordinate.tag.value)
                    calendarEventsToRsvps.removeValue(forKey: deletedEventCoordinate.tag.value)
                    persistentNostrEvents.removeValue(forKey: timeBasedCalendarEvent.id)
                }
            case .calendarEventRSVP:
                if let rsvp = rsvps[deletedEventCoordinate.tag.value], rsvp.createdAt <= deletionEvent.createdAt {
                    rsvps.removeValue(forKey: deletedEventCoordinate.tag.value)
                    if let calendarEventCoordinates = rsvp.calendarEventCoordinates?.tag.value {
                        calendarEventsToRsvps[calendarEventCoordinates]?.removeAll(where: { $0 == rsvp })
                    }
                    persistentNostrEvents.removeValue(forKey: rsvp.id)
                }
            default:
                continue
            }
        }
    }

    private func deleteFromEventIds(_ deletionEvent: DeletionEvent) {
        for deletedEventId in deletionEvent.deletedEventIds {
            if let persistentNostrEvent = persistentNostrEvents[deletedEventId] {
                let nostrEvent = persistentNostrEvent.nostrEvent

                guard nostrEvent.pubkey == deletionEvent.pubkey else {
                    continue
                }

                switch nostrEvent {
                case _ as FollowListEvent:
                    followListEvents.removeValue(forKey: nostrEvent.pubkey)
                case _ as MetadataEvent:
                    metadataEvents.removeValue(forKey: nostrEvent.pubkey)
                case let calendarListEvent as CalendarListEvent:
                    if let eventCoordinates = calendarListEvent.replaceableEventCoordinates()?.tag.value, calendarListEvents[eventCoordinates]?.id == calendarListEvent.id {
                        calendarListEvents.removeValue(forKey: eventCoordinates)
                    }
                case let timeBasedCalendarEvent as TimeBasedCalendarEvent:
                    if let eventCoordinates = timeBasedCalendarEvent.replaceableEventCoordinates()?.tag.value, timeBasedCalendarEvents[eventCoordinates]?.id == timeBasedCalendarEvent.id {
                        timeBasedCalendarEvents.removeValue(forKey: eventCoordinates)
                        calendarEventsToRsvps.removeValue(forKey: eventCoordinates)
                    }
                case let rsvp as CalendarEventRSVP:
                    if let eventCoordinates = rsvp.replaceableEventCoordinates()?.tag.value, rsvps[eventCoordinates]?.id == rsvp.id {
                        rsvps.removeValue(forKey: eventCoordinates)

                        if let calendarEventCoordinates = rsvp.calendarEventCoordinates?.tag.value {
                            calendarEventsToRsvps[calendarEventCoordinates]?.removeAll(where: { $0.id == rsvp.id })
                        }
                    }

                    rsvps.removeValue(forKey: nostrEvent.pubkey)
                default:
                    continue
                }

                persistentNostrEvents.removeValue(forKey: deletedEventId)
                modelContext.delete(persistentNostrEvent)
                do {
                    try modelContext.save()
                } catch {
                    print("Unable to delete PersistentNostrEvent with id \(deletedEventId)")
                }
            }
        }
    }

    private func didReceiveDeletionEvent(_ deletionEvent: DeletionEvent) {
        deleteFromEventCoordinates(deletionEvent)
        deleteFromEventIds(deletionEvent)
    }

    func relay(_ relay: Relay, didReceive event: RelayEvent) {
        DispatchQueue.main.async {
            let nostrEvent = event.event

            // Verify the id and signature of the event.
            // If the verification throws an error, that means they are invalid and we should ignore the event.
            try? self.verifyEvent(nostrEvent)

            if let existingEvent = self.persistentNostrEvents[nostrEvent.id] {
                if !existingEvent.relays.contains(where: { $0 == relay.url }) {
                    existingEvent.relays.append(relay.url)
                }
            } else {
                let persistentNostrEvent = PersistentNostrEvent(nostrEvent: nostrEvent, relays: [relay.url])
                self.persistentNostrEvents[persistentNostrEvent.nostrEvent.id] = persistentNostrEvent
                self.modelContext.insert(persistentNostrEvent)
                do {
                    try self.modelContext.save()
                } catch {
                    print("Failed to save PersistentNostrEvent. id=\(nostrEvent.id)")
                }
            }

            switch nostrEvent {
            case let followListEvent as FollowListEvent:
                self.didReceiveFollowListEvent(followListEvent, shouldPullMissingMetadata: true)
            case let metadataEvent as MetadataEvent:
                self.didReceiveMetadataEvent(metadataEvent)
            case let calendarListEvent as CalendarListEvent:
                self.didReceiveCalendarListEvent(calendarListEvent, shouldPullMissingMetadata: true)
            case let timeBasedCalendarEvent as TimeBasedCalendarEvent:
                self.didReceiveTimeBasedCalendarEvent(timeBasedCalendarEvent, shouldPullMissingMetadata: true)
            case let rsvpEvent as CalendarEventRSVP:
                self.didReceiveCalendarEventRSVP(rsvpEvent)
            case let deletionEvent as DeletionEvent:
                self.didReceiveDeletionEvent(deletionEvent)
            default:
                break
            }
        }
    }

    func loadPersistentNostrEvents(_ persistentNostrEvents: [PersistentNostrEvent]) {
        for persistentNostrEvent in persistentNostrEvents {
            if let existingEvent = self.persistentNostrEvents[persistentNostrEvent.nostrEvent.id] {
                let missingRelays = Set(persistentNostrEvent.relays).subtracting(Set(existingEvent.relays))
                existingEvent.relays.append(contentsOf: missingRelays)
            } else {
                self.persistentNostrEvents[persistentNostrEvent.nostrEvent.id] = persistentNostrEvent

                switch persistentNostrEvent.nostrEvent {
                case let followListEvent as FollowListEvent:
                    self.didReceiveFollowListEvent(followListEvent)
                case let metadataEvent as MetadataEvent:
                    self.didReceiveMetadataEvent(metadataEvent)
                case let calendarListEvent as CalendarListEvent:
                    self.didReceiveCalendarListEvent(calendarListEvent)
                case let timeBasedCalendarEvent as TimeBasedCalendarEvent:
                    self.didReceiveTimeBasedCalendarEvent(timeBasedCalendarEvent)
                case let rsvpEvent as CalendarEventRSVP:
                    self.didReceiveCalendarEventRSVP(rsvpEvent)
                case let deletionEvent as DeletionEvent:
                    self.didReceiveDeletionEvent(deletionEvent)
                default:
                    break
                }
            }
        }

        if let publicKey, let followListEvent = followListEvents[publicKey.hex] {
            pullMissingMetadata(followListEvent.followedPubkeys)
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
