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

    @Published var relayReadPool: RelayPool = RelayPool(relays: [])
    @Published var relayWritePool: RelayPool = RelayPool(relays: [])

    @Published var activeTab: HomeTabs = .following

    @Published var followListEvents: [String: FollowListEvent] = [:]
    @Published var metadataEvents: [String: MetadataEvent] = [:]
    @Published var timeBasedCalendarEvents: [String: TimeBasedCalendarEvent] = [:]
    @Published var rsvps: [String: CalendarEventRSVP] = [:]
    @Published var calendarEventsToRsvps: [String: [CalendarEventRSVP]] = [:]

    @Published var followedPubkeys = Set<String>()

    @Published var appSettings: AppSettings?
    @Published var profiles: [Profile] = []

    @Published var metadataTrie = Trie<MetadataEvent>()

    // Keep track of relay pool active subscriptions and the until filter so that we can limit the scope of how much we query from the relay pools.
    var metadataSubscriptionCounts = [String: Int]()
    var metadataSubscriptionDates = [String: Date]()
    var bootstrapSubscriptionCounts = [String: Int]()
    var bootstrapSubscriptionDates = [String: Date]()
    var timeBasedCalendarEventSubscriptionCounts = [String: Int]()
    var timeBasedCalendarEventSubscriptionDates = [String: Date]()

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

    var activeFollowList: FollowListEvent? {
        guard let publicKeyHex = publicKey?.hex else {
            return nil
        }

        return followListEvents[publicKeyHex]
    }

    func refreshFollowedPubkeys() {
        followedPubkeys.removeAll()
        if let publicKey {
            followedPubkeys.insert(publicKey.hex)
            if let activeFollowList {
                followedPubkeys.formUnion(activeFollowList.followedPubkeys)
            }
        }
    }

    private var followedRSVPCalendarEventCoordinates: Set<String> {
        guard publicKey != nil else {
            return []
        }

        return Set(
            rsvps.values
                .filter { followedPubkeys.contains($0.pubkey) }
                .compactMap { $0.calendarEventCoordinates?.tag.value })
    }

    /// Events that were created or RSVP'd by follow list.
    private var followedEvents: [TimeBasedCalendarEvent] {
        guard publicKey != nil else {
            return []
        }

        let followedRSVPCalendarEventCoordinates = followedRSVPCalendarEventCoordinates

        return timeBasedCalendarEvents.values.filter { event in
            guard let coordinates = event.replaceableEventCoordinates() else {
                return false
            }

            return event.startTimestamp != nil
            && (followedPubkeys.contains(event.pubkey)
                || followedRSVPCalendarEventCoordinates.contains(coordinates.tag.value))
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
        events.filter { $0.isUpcoming }
            .sorted(using: TimeBasedCalendarEventSortComparator(order: .forward))
    }

    private func pastEvents(_ events: [TimeBasedCalendarEvent]) -> [TimeBasedCalendarEvent] {
        events.filter { $0.isPast }
            .sorted(using: TimeBasedCalendarEventSortComparator(order: .reverse))
    }

    func updateRelayPool() {
        let profile = appSettings?.activeProfile

        let relaySettings = profile?.profileSettings?.relayPoolSettings?.relaySettingsList ?? []

        let readRelays = relaySettings
            .filter { $0.read }
            .compactMap { URL(string: $0.relayURLString) }
            .compactMap { try? Relay(url: $0) }

        let writeRelays = relaySettings
            .filter { $0.read }
            .compactMap { URL(string: $0.relayURLString) }
            .compactMap { try? Relay(url: $0) }

        let readRelaySet = Set(readRelays)
        let writeRelaySet = Set(writeRelays)

        let oldReadRelays = relayReadPool.relays.subtracting(readRelaySet)
        let newReadRelays = readRelaySet.subtracting(relayReadPool.relays)

        relayReadPool.delegate = self

        oldReadRelays.forEach {
            relayReadPool.remove(relay: $0)
        }
        newReadRelays.forEach {
            relayReadPool.add(relay: $0)
        }

        let oldWriteRelays = relayWritePool.relays.subtracting(writeRelaySet)
        let newWriteRelays = writeRelaySet.subtracting(relayWritePool.relays)

        relayWritePool.delegate = self

        oldWriteRelays.forEach {
            relayWritePool.remove(relay: $0)
        }
        newWriteRelays.forEach {
            relayWritePool.add(relay: $0)
        }
    }

    func persistentNostrEvent(_ eventId: String) -> PersistentNostrEvent? {
        let descriptor = FetchDescriptor<PersistentNostrEvent>(
            predicate: #Predicate { $0.eventId == eventId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    var relaySubscriptionMetadata: RelaySubscriptionMetadata? {
        let descriptor = FetchDescriptor<RelaySubscriptionMetadata>()

        if let result = try? modelContext.fetch(descriptor).first {
            return result
        } else {
            let result = RelaySubscriptionMetadata()
            modelContext.insert(result)
            do {
                try modelContext.save()
            } catch {
                print("Unable to save initial RelaySubscriptionMetadata object.")
            }
            return result
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
        // There has to be at least one connected relay to be able to pull metadata.
        guard !relayReadPool.relays.isEmpty && relayReadPool.relays.contains(where: { $0.state == .connected }) else {
            return
        }

        let relaySubscriptionMetadata = relaySubscriptionMetadata

        let since: Int?
        if let lastPulledMetadataEvents = relaySubscriptionMetadata?.lastPulledMetadataEvents {
            since = Int(lastPulledMetadataEvents.timeIntervalSince1970) + 1
        } else {
            since = nil
        }
        let until = Date.now

        let allPubkeysSet = Set(pubkeys)
        let pubkeysToFetchMetadata = allPubkeysSet.filter { self.metadataEvents[$0] == nil }
        if !pubkeysToFetchMetadata.isEmpty {
            guard let missingMetadataFilter = Filter(
                authors: Array(pubkeysToFetchMetadata),
                kinds: [EventKind.metadata.rawValue]
            ) else {
                print("Unable to create missing metadata filter for \(pubkeysToFetchMetadata).")
                return
            }

            _ = relayReadPool.subscribe(with: missingMetadataFilter)
        }

        if !metadataSubscriptionCounts.isEmpty {
            // Do not refresh metadata if one is already in progress.
            return
        }

        let pubkeysToRefresh = allPubkeysSet.subtracting(pubkeysToFetchMetadata)
        guard let metadataRefreshFilter = Filter(
            authors: Array(pubkeysToRefresh),
            kinds: [EventKind.metadata.rawValue],
            since: since
        ) else {
            print("Unable to create refresh metadata filter for \(pubkeysToRefresh).")
            return
        }

        relaySubscriptionMetadata?.lastPulledMetadataEvents = until
        _ = relayReadPool.subscribe(with: metadataRefreshFilter)

    }

    /// Subscribe with filter to relay if provided, or use relay read pool if not.
    func subscribe(filter: Filter, relay: Relay? = nil) throws -> String? {
        if let relay {
            do {
                return try relay.subscribe(with: filter)
            } catch {
                print("Could not subscribe to relay with filter.")
                return nil
            }
        } else {
            return relayReadPool.subscribe(with: filter)
        }
    }

    func refresh(relay: Relay? = nil) {
        guard (relay == nil && !relayReadPool.relays.isEmpty && relayReadPool.relays.contains(where: { $0.state == .connected })) || relay?.state == .connected else {
            return
        }

        let relaySubscriptionMetadata = relaySubscriptionMetadata
        let until = Date.now

        if bootstrapSubscriptionCounts.isEmpty {
            let authors = profiles.compactMap({ $0.publicKeyHex })
            if !authors.isEmpty {
                let since: Int?
                if let lastBootstrapped = relaySubscriptionMetadata?.lastBootstrapped {
                    since = Int(lastBootstrapped.timeIntervalSince1970) + 1
                } else {
                    since = nil
                }

                guard let bootstrapFilter = Filter(
                    authors: authors,
                    kinds: [EventKind.metadata.rawValue, EventKind.followList.rawValue, EventKind.timeBasedCalendarEvent.rawValue, EventKind.calendarEventRSVP.rawValue, EventKind.deletion.rawValue],
                    since: since
                ) else {
                    print("Unable to create the boostrap filter.")
                    return
                }

                do {
                    if let bootstrapSubscriptionId = try subscribe(filter: bootstrapFilter, relay: relay), relay == nil {
                        if let bootstrapSubscriptionCount = bootstrapSubscriptionCounts[bootstrapSubscriptionId] {
                            bootstrapSubscriptionCounts[bootstrapSubscriptionId] = bootstrapSubscriptionCount + 1
                        } else {
                            bootstrapSubscriptionCounts[bootstrapSubscriptionId] = 1
                        }
                    }
                } catch {
                    print("Could not subscribe to relay with the boostrap filter.")
                }
            }
        }

        if timeBasedCalendarEventSubscriptionCounts.isEmpty {
            let since: Int?
            if let lastPulledAllTimeBasedCalendarEvents = relaySubscriptionMetadata?.lastPulledAllTimeBasedCalendarEvents {
                since = Int(lastPulledAllTimeBasedCalendarEvents.timeIntervalSince1970) + 1
            } else {
                since = nil
            }

            guard let timeBasedCalendarEventFilter = Filter(
                kinds: [EventKind.timeBasedCalendarEvent.rawValue],
                since: since
            ) else {
                print("Unable to create the time-based calendar event filter.")
                return
            }

            do {
                if let timeBasedCalendarEventSubscriptionId = try subscribe(filter: timeBasedCalendarEventFilter, relay: relay), relay == nil {
                    if let timeBasedCalendarEventSubscriptionCount = timeBasedCalendarEventSubscriptionCounts[timeBasedCalendarEventSubscriptionId] {
                        timeBasedCalendarEventSubscriptionCounts[timeBasedCalendarEventSubscriptionId] = timeBasedCalendarEventSubscriptionCount + 1
                    } else {
                        timeBasedCalendarEventSubscriptionCounts[timeBasedCalendarEventSubscriptionId] = 1
                    }
                }
            } catch {
                print("Could not subscribe to relay with the time-based calendar event filter.")
            }
        }
    }

    private func didReceiveFollowListEvent(_ followListEvent: FollowListEvent, shouldPullMissingMetadata: Bool = false) {
        if let existingFollowList = self.followListEvents[followListEvent.pubkey] {
            if existingFollowList.createdAt < followListEvent.createdAt {
                cache(followListEvent, shouldPullMissingMetadata: shouldPullMissingMetadata)
            }
        } else {
            cache(followListEvent, shouldPullMissingMetadata: shouldPullMissingMetadata)
        }
    }

    private func cache(_ followListEvent: FollowListEvent, shouldPullMissingMetadata: Bool) {
        self.followListEvents[followListEvent.pubkey] = followListEvent

        if shouldPullMissingMetadata {
            pullMissingMetadata(followListEvent.followedPubkeys)
        }

        // TODO Here or elsewhere. Query for calendar events that follows who have RSVP'd.
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

    private func didReceiveTimeBasedCalendarEvent(_ timeBasedCalendarEvent: TimeBasedCalendarEvent) {
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
            case .timeBasedCalendarEvent:
                if let timeBasedCalendarEvent = timeBasedCalendarEvents[deletedEventCoordinate.tag.value], timeBasedCalendarEvent.createdAt <= deletionEvent.createdAt {
                    timeBasedCalendarEvents.removeValue(forKey: deletedEventCoordinate.tag.value)
                    calendarEventsToRsvps.removeValue(forKey: deletedEventCoordinate.tag.value)
                }
            case .calendarEventRSVP:
                if let rsvp = rsvps[deletedEventCoordinate.tag.value], rsvp.createdAt <= deletionEvent.createdAt {
                    rsvps.removeValue(forKey: deletedEventCoordinate.tag.value)
                    if let calendarEventCoordinates = rsvp.calendarEventCoordinates?.tag.value {
                        calendarEventsToRsvps[calendarEventCoordinates]?.removeAll(where: { $0 == rsvp })
                    }
                }
            default:
                continue
            }
        }
    }

    private func deleteFromEventIds(_ deletionEvent: DeletionEvent) {
        for deletedEventId in deletionEvent.deletedEventIds {
            if let persistentNostrEvent = persistentNostrEvent(deletedEventId) {
                let nostrEvent = persistentNostrEvent.nostrEvent

                guard nostrEvent.pubkey == deletionEvent.pubkey else {
                    continue
                }

                switch nostrEvent {
                case _ as FollowListEvent:
                    followListEvents.removeValue(forKey: nostrEvent.pubkey)
                case _ as MetadataEvent:
                    metadataEvents.removeValue(forKey: nostrEvent.pubkey)
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

            if let existingEvent = self.persistentNostrEvent(nostrEvent.id) {
                if !existingEvent.relays.contains(where: { $0 == relay.url }) {
                    existingEvent.relays.append(relay.url)
                }
            } else {
                let persistentNostrEvent = PersistentNostrEvent(nostrEvent: nostrEvent, relays: [relay.url])
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

    func loadPersistentNostrEvents(_ persistentNostrEvents: [PersistentNostrEvent]) {
        for persistentNostrEvent in persistentNostrEvents {
            switch persistentNostrEvent.nostrEvent {
            case let followListEvent as FollowListEvent:
                self.didReceiveFollowListEvent(followListEvent)
            case let metadataEvent as MetadataEvent:
                self.didReceiveMetadataEvent(metadataEvent)
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

        if let publicKey, let followListEvent = followListEvents[publicKey.hex] {
            pullMissingMetadata(followListEvent.followedPubkeys)
        }
    }

    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        switch response {
        case let .eose(subscriptionId):
            // Live new events are not strictly needed for this app for now.
            // In the future, we could keep subscriptions open for updates.
            try? relay.closeSubscription(with: subscriptionId)
            updateRelaySubscriptionMetadataTimestamps(with: subscriptionId)
            updateRelaySubscriptionCounts(closedSubscriptionId: subscriptionId)
        case let .closed(subscriptionId, _):
            updateRelaySubscriptionCounts(closedSubscriptionId: subscriptionId)
        case let .ok(eventId, success, message):
            if success {
                if let persistentNostrEvent = persistentNostrEvent(eventId), !persistentNostrEvent.relays.contains(relay.url) {
                    persistentNostrEvent.relays.append(relay.url)
                }
            } else if message.prefix == .rateLimited {
                // TODO retry with exponential backoff.
            }
        default:
            break
        }
    }

    func updateRelaySubscriptionCounts(closedSubscriptionId: String) {
        if let metadataSubscriptionCount = metadataSubscriptionCounts[closedSubscriptionId] {
            if metadataSubscriptionCount <= 1 {
                metadataSubscriptionCounts.removeValue(forKey: closedSubscriptionId)
            } else {
                metadataSubscriptionCounts[closedSubscriptionId] = metadataSubscriptionCount - 1
            }
        }

        if let bootstrapSubscriptionCount = bootstrapSubscriptionCounts[closedSubscriptionId] {
            if bootstrapSubscriptionCount <= 1 {
                bootstrapSubscriptionCounts.removeValue(forKey: closedSubscriptionId)
            } else {
                bootstrapSubscriptionCounts[closedSubscriptionId] = bootstrapSubscriptionCount - 1
            }
        }

        if let timeBasedCalendarEventSubscriptionCount = timeBasedCalendarEventSubscriptionCounts[closedSubscriptionId] {
            if timeBasedCalendarEventSubscriptionCount <= 1 {
                timeBasedCalendarEventSubscriptionCounts.removeValue(forKey: closedSubscriptionId)

                // Wait until we have fetched all the time-based calendar events before fetching metadata in bulk.
                pullMissingMetadata(timeBasedCalendarEvents.values.map { $0.pubkey })
            } else {
                timeBasedCalendarEventSubscriptionCounts[closedSubscriptionId] = timeBasedCalendarEventSubscriptionCount - 1
            }
        }
    }

    func updateRelaySubscriptionMetadataTimestamps(with subscriptionId: String) {
        let relaySubscriptionMetadata = relaySubscriptionMetadata

        if let relaySubscriptionMetadata,
           let lastPulledMetadataEvents = relaySubscriptionMetadata.lastPulledMetadataEvents,
           let metadataSubscriptionDate = metadataSubscriptionDates[subscriptionId] {
            if lastPulledMetadataEvents < metadataSubscriptionDate {
                relaySubscriptionMetadata.lastPulledMetadataEvents = metadataSubscriptionDate
            }
            metadataSubscriptionDates.removeValue(forKey: subscriptionId)
        }

        if let relaySubscriptionMetadata,
           let lastBootstrapped = relaySubscriptionMetadata.lastBootstrapped,
           let bootstrapSubscriptionDate = bootstrapSubscriptionDates[subscriptionId] {
            if lastBootstrapped < bootstrapSubscriptionDate {
                relaySubscriptionMetadata.lastPulledMetadataEvents = bootstrapSubscriptionDate
            }
            bootstrapSubscriptionDates.removeValue(forKey: subscriptionId)
        }

        if let relaySubscriptionMetadata,
           let lastPulledAllTimeBasedCalendarEvents = relaySubscriptionMetadata.lastPulledAllTimeBasedCalendarEvents,
           let timeBasedCalendarEventSubscriptionDate = timeBasedCalendarEventSubscriptionDates[subscriptionId] {
            if lastPulledAllTimeBasedCalendarEvents < timeBasedCalendarEventSubscriptionDate {
                relaySubscriptionMetadata.lastPulledAllTimeBasedCalendarEvents = timeBasedCalendarEventSubscriptionDate
            }
            timeBasedCalendarEventSubscriptionDates.removeValue(forKey: subscriptionId)
        }
    }

}

enum HomeTabs {
    case following
    case explore
}
