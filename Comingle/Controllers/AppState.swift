//
//  AppState.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import Foundation
import NostrSDK
import OrderedCollections
import SwiftData
import SwiftTrie

class AppState: ObservableObject, Hashable, RelayURLValidating, EventCreating {
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

    @Published var activeTab: HomeTabs = .events

    @Published var followListEvents: [String: FollowListEvent] = [:]
    @Published var metadataEvents: [String: MetadataEvent] = [:]
    @Published var timeBasedCalendarEvents: [String: TimeBasedCalendarEvent] = [:]
    @Published var calendarListEvents: [String: CalendarListEvent] = [:]
    @Published var rsvps: [String: CalendarEventRSVP] = [:]
    @Published var calendarEventsToRsvps: [String: [CalendarEventRSVP]] = [:]
    @Published var deletedEventIds = Set<String>()
    @Published var deletedEventCoordinates = [String: Date]()

    @Published var followedPubkeys = Set<String>()

    @Published var eventsTrie = Trie<String>()
    @Published var calendarsTrie = Trie<String>()
    @Published var pubkeyTrie = Trie<String>()

    // Keep track of relay pool active subscriptions and the until filter so that we can limit the scope of how much we query from the relay pools.
    var metadataSubscriptionCounts = [String: Int]()
    var bootstrapSubscriptionCounts = [String: Int]()
    var timeBasedCalendarEventSubscriptionCounts = [String: Int]()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var publicKey: PublicKey? {
        if let publicKeyHex = appSettings?.activeProfile?.publicKeyHex {
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

    private func eventsOnCalendarList(_ calendarCoordinates: String) -> [TimeBasedCalendarEvent] {
        guard let calendarListEvent = calendarListEvents[calendarCoordinates] else {
            return []
        }

        return calendarListEvent.calendarEventCoordinateList.compactMap { timeBasedCalendarEvents[$0.tag.value] }
    }

    func upcomingEventsOnCalendarList(_ calendarCoordinates: String) -> [TimeBasedCalendarEvent] {
        upcomingEvents(eventsOnCalendarList(calendarCoordinates))
    }

    func pastEventsOnCalendarList(_ calendarCoordinates: String) -> [TimeBasedCalendarEvent] {
        pastEvents(eventsOnCalendarList(calendarCoordinates))
    }

    func upcomingEvents(_ events: [TimeBasedCalendarEvent]) -> [TimeBasedCalendarEvent] {
        events.filter { $0.isUpcoming }
            .sorted(using: TimeBasedCalendarEventSortComparator(order: .forward))
    }

    func pastEvents(_ events: [TimeBasedCalendarEvent]) -> [TimeBasedCalendarEvent] {
        events.filter { $0.isPast }
            .sorted(using: TimeBasedCalendarEventSortComparator(order: .reverse))
    }

    func updateRelayPool() {
        let relaySettings = relayPoolSettings?.relaySettingsList ?? []

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
        var descriptor = FetchDescriptor<PersistentNostrEvent>(
            predicate: #Predicate { $0.eventId == eventId }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    var unpublishedPersistentNostrEvents: [PersistentNostrEvent] {
        let descriptor = FetchDescriptor<PersistentNostrEvent>(
            predicate: #Predicate { $0.relays == [] }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var relaySubscriptionMetadata: RelaySubscriptionMetadata? {
        let publicKeyHex = publicKey?.hex
        var descriptor = FetchDescriptor<RelaySubscriptionMetadata>(
            predicate: #Predicate { $0.publicKeyHex == publicKeyHex }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    var relayPoolSettings: RelayPoolSettings? {
        let publicKeyHex = publicKey?.hex
        var descriptor = FetchDescriptor<RelayPoolSettings>(
            predicate: #Predicate { $0.publicKeyHex == publicKeyHex }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func addRelay(relayURL: URL) {
        guard let relayPoolSettings, relayPoolSettings.relaySettingsList.allSatisfy({ $0.relayURLString != relayURL.absoluteString }) else {
            return
        }

        relayPoolSettings.relaySettingsList.append(RelaySettings(relayURLString: relayURL.absoluteString))

        updateRelayPool()
    }

    func removeRelaySettings(relaySettings: RelaySettings) {
        relayPoolSettings?.relaySettingsList.removeAll(where: { $0 == relaySettings })
        updateRelayPool()
    }

    func deleteProfile(_ profile: Profile) {
        guard let publicKeyHex = profile.publicKeyHex, let newProfile = profiles.first(where: { $0 != profile }) else {
            return
        }

        if let publicKey = PublicKey(hex: publicKeyHex) {
            privateKeySecureStorage.delete(for: publicKey)
        }
        if let appSettings, appSettings.activeProfile == profile {
            updateActiveProfile(newProfile)
            refreshFollowedPubkeys()
        }
        modelContext.delete(profile)
    }

    func updateActiveProfile(_ profile: Profile) {
        guard let appSettings, appSettings.activeProfile != profile else {
            return
        }

        appSettings.activeProfile = profile

        followedPubkeys.removeAll()

        if profile.publicKeyHex == nil {
            activeTab = .events
        } else if publicKey != nil {
            refreshFollowedPubkeys()
        }

        updateRelayPool()
        refresh(hardRefresh: true)
    }

    func signIn(keypair: Keypair, relayURLs: [URL]) {
        signIn(publicKey: keypair.publicKey, relayURLs: relayURLs)
        privateKeySecureStorage.store(for: keypair)
    }

    func signIn(publicKey: PublicKey, relayURLs: [URL]) {
        guard let appSettings, appSettings.activeProfile?.publicKeyHex != publicKey.hex else {
            return
        }

        let validatedRelayURLStrings = OrderedSet<String>(relayURLs.compactMap { try? validateRelayURL($0).absoluteString })

        if let profile = profiles.first(where: { $0.publicKeyHex == publicKey.hex }) {
            print("Found existing profile settings for \(publicKey.npub)")
            if let relayPoolSettings = profile.profileSettings?.relayPoolSettings {
                let existingRelayURLStrings = Set(relayPoolSettings.relaySettingsList.map { $0.relayURLString })
                let newRelayURLStrings = validatedRelayURLStrings.subtracting(existingRelayURLStrings)
                if !newRelayURLStrings.isEmpty {
                    relayPoolSettings.relaySettingsList += newRelayURLStrings.map { RelaySettings(relayURLString: $0) }
                }
            }
            appSettings.activeProfile = profile
        } else {
            print("Creating new profile settings for \(publicKey.npub)")
            let profile = Profile(publicKeyHex: publicKey.hex)
            modelContext.insert(profile)
            do {
                try modelContext.save()
            } catch {
                print("Unable to save new profile \(publicKey.npub)")
            }
            if let relayPoolSettings = profile.profileSettings?.relayPoolSettings {
                relayPoolSettings.relaySettingsList += validatedRelayURLStrings.map { RelaySettings(relayURLString: $0) }
            }
            appSettings.activeProfile = profile

            // Remove private key from secure storage in case for whatever reason it was not cleaned up previously.
            privateKeySecureStorage.delete(for: publicKey)
        }

        refreshFollowedPubkeys()
        updateRelayPool()
        pullMissingEventsFromPubkeysAndFollows([publicKey.hex])
        refresh()
    }

    var profiles: [Profile] {
        let profileDescriptor = FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.publicKeyHex)])
        return (try? modelContext.fetch(profileDescriptor)) ?? []
    }

    var appSettings: AppSettings? {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    var appearanceSettings: AppearanceSettings? {
        var descriptor = FetchDescriptor<AppearanceSettings>()
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    func relayState(relayURLString: String) -> Relay.State? {
        let readRelay = relayReadPool.relays.first(where: { $0.url.absoluteString == relayURLString })
        let writeRelay = relayWritePool.relays.first(where: { $0.url.absoluteString == relayURLString })

        switch (readRelay?.state, writeRelay?.state) {
        case (nil, nil):
            return nil
        case (_, .error):
            return writeRelay?.state
        case (.error, _):
            return readRelay?.state
        case (_, .notConnected), (.notConnected, _):
            return .notConnected
        case (_, .connecting), (.connecting, _):
            return .connecting
        case (_, .connected), (.connected, _):
            return .connected
        }
    }
}

extension AppState: EventVerifying, RelayDelegate {

    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        guard relayReadPool.relays.contains(relay) || relayWritePool.relays.contains(relay) else {
            print("Relay \(relay.url.absoluteString) changed state to \(state) but it is not in the read or write relay pool. Doing nothing.")
            return
        }

        print("Relay \(relay.url.absoluteString) changed state to \(state)")
        switch state {
        case .connected:
            refresh(relay: relay)
        case .notConnected, .error:
            relay.connect()
        default:
            break
        }
    }

    func pullMissingEventsFromPubkeysAndFollows(_ pubkeys: [String]) {
        // There has to be at least one connected relay to be able to pull metadata.
        guard !relayReadPool.relays.isEmpty && relayReadPool.relays.contains(where: { $0.state == .connected }) else {
            return
        }

        let until = Date.now

        let allPubkeysSet = Set(pubkeys)
        let pubkeysToFetchMetadata = allPubkeysSet.filter { self.metadataEvents[$0] == nil }
        if !pubkeysToFetchMetadata.isEmpty {
            guard let missingMetadataFilter = Filter(
                authors: Array(pubkeysToFetchMetadata),
                kinds: [EventKind.metadata.rawValue, EventKind.timeBasedCalendarEvent.rawValue, EventKind.calendarEventRSVP.rawValue, EventKind.calendar.rawValue, EventKind.deletion.rawValue],
                until: Int(until.timeIntervalSince1970)
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

        let since: Int?
        if let lastPulledEventsFromFollows = relaySubscriptionMetadata?.lastPulledEventsFromFollows.values.min() {
            since = Int(lastPulledEventsFromFollows.timeIntervalSince1970) + 1
        } else {
            since = nil
        }

        let pubkeysToRefresh = allPubkeysSet.subtracting(pubkeysToFetchMetadata)
        guard let metadataRefreshFilter = Filter(
            authors: Array(pubkeysToRefresh),
            kinds: [EventKind.metadata.rawValue, EventKind.timeBasedCalendarEvent.rawValue, EventKind.calendarEventRSVP.rawValue, EventKind.calendar.rawValue, EventKind.deletion.rawValue],
            since: since,
            until: Int(until.timeIntervalSince1970)
        ) else {
            print("Unable to create refresh metadata filter for \(pubkeysToRefresh).")
            return
        }

        relayReadPool.relays.forEach {
            relaySubscriptionMetadata?.lastPulledEventsFromFollows[$0.url] = until
        }
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

    func refresh(relay: Relay? = nil, hardRefresh: Bool = false) {
        guard (relay == nil && !relayReadPool.relays.isEmpty && relayReadPool.relays.contains(where: { $0.state == .connected })) || relay?.state == .connected else {
            return
        }

        let relaySubscriptionMetadata = relaySubscriptionMetadata
        let until = Date.now

        if bootstrapSubscriptionCounts.isEmpty {
            let authors = profiles.compactMap({ $0.publicKeyHex })
            if !authors.isEmpty {
                let since: Int?
                if let relaySubscriptionMetadata, !hardRefresh {
                    if let relayURL = relay?.url, let lastBootstrapped = relaySubscriptionMetadata.lastBootstrapped[relayURL] {
                        since = Int(lastBootstrapped.timeIntervalSince1970) + 1
                    } else if let lastBootstrapped = relaySubscriptionMetadata.lastBootstrapped.values.min() {
                        since = Int(lastBootstrapped.timeIntervalSince1970) + 1
                    } else {
                        since = nil
                    }
                } else {
                    since = nil
                }

                guard let bootstrapFilter = Filter(
                    authors: authors,
                    kinds: [EventKind.metadata.rawValue, EventKind.followList.rawValue, EventKind.timeBasedCalendarEvent.rawValue, EventKind.calendarEventRSVP.rawValue, EventKind.calendar.rawValue, EventKind.deletion.rawValue],
                    since: since,
                    until: Int(until.timeIntervalSince1970)
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
            if let relaySubscriptionMetadata, !hardRefresh {
                if let relayURL = relay?.url, let lastPulledAllTimeBasedCalendarEvents = relaySubscriptionMetadata.lastPulledAllTimeBasedCalendarEvents[relayURL] {
                    since = Int(lastPulledAllTimeBasedCalendarEvents.timeIntervalSince1970) + 1
                } else if let lastPulledAllTimeBasedCalendarEvents = relaySubscriptionMetadata.lastBootstrapped.values.min() {
                    since = Int(lastPulledAllTimeBasedCalendarEvents.timeIntervalSince1970) + 1
                } else {
                    since = nil
                }
            } else {
                since = nil
            }

            guard let timeBasedCalendarEventFilter = Filter(
                kinds: [EventKind.timeBasedCalendarEvent.rawValue, EventKind.calendar.rawValue],
                since: since,
                until: Int(until.timeIntervalSince1970)
            ) else {
                print("Unable to create the time-based calendar event filter.")
                return
            }

            do {
                if let timeBasedCalendarEventSubscriptionId = try subscribe(filter: timeBasedCalendarEventFilter, relay: relay) {
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

        publishUnpublishedEvents()
    }

    private func publishUnpublishedEvents() {
        for persistentNostrEvent in unpublishedPersistentNostrEvents {
            relayWritePool.publishEvent(persistentNostrEvent.nostrEvent)
        }
    }

    private func didReceiveFollowListEvent(_ followListEvent: FollowListEvent, shouldPullMissingEvents: Bool = false) {
        if let existingFollowList = self.followListEvents[followListEvent.pubkey] {
            if existingFollowList.createdAt < followListEvent.createdAt {
                cache(followListEvent, shouldPullMissingEvents: shouldPullMissingEvents)
            }
        } else {
            cache(followListEvent, shouldPullMissingEvents: shouldPullMissingEvents)
        }
    }

    private func cache(_ followListEvent: FollowListEvent, shouldPullMissingEvents: Bool) {
        self.followListEvents[followListEvent.pubkey] = followListEvent

        if shouldPullMissingEvents {
            pullMissingEventsFromPubkeysAndFollows(followListEvent.followedPubkeys)
        }

        if followListEvent.pubkey == publicKey?.hex {
            refreshFollowedPubkeys()
        }
    }

    private func didReceiveMetadataEvent(_ metadataEvent: MetadataEvent) {
        let newUserMetadata = metadataEvent.userMetadata
        let newName = newUserMetadata?.name?.trimmedOrNilIfEmpty
        let newDisplayName = newUserMetadata?.displayName?.trimmedOrNilIfEmpty

        if let existingMetadataEvent = self.metadataEvents[metadataEvent.pubkey] {
            if existingMetadataEvent.createdAt < metadataEvent.createdAt {
                if let existingUserMetadata = existingMetadataEvent.userMetadata {
                    if let existingName = existingUserMetadata.name?.trimmedOrNilIfEmpty, existingName != newName {
                        pubkeyTrie.remove(key: existingName, value: existingMetadataEvent.pubkey)
                    }
                    if let existingDisplayName = existingUserMetadata.displayName?.trimmedOrNilIfEmpty, existingDisplayName != newDisplayName {
                        pubkeyTrie.remove(key: existingDisplayName, value: existingMetadataEvent.pubkey)
                    }
                }
            } else {
                return
            }
        }

        self.metadataEvents[metadataEvent.pubkey] = metadataEvent

        if let userMetadata = metadataEvent.userMetadata {
            if let name = userMetadata.name?.trimmingCharacters(in: .whitespacesAndNewlines) {
                _ = pubkeyTrie.insert(key: name, value: metadataEvent.pubkey, options: [.includeCaseInsensitiveMatches, .includeDiacriticsInsensitiveMatches, .includeNonPrefixedMatches])
            }
            if let displayName = userMetadata.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) {
                _ = pubkeyTrie.insert(key: displayName, value: metadataEvent.pubkey, options: [.includeCaseInsensitiveMatches, .includeDiacriticsInsensitiveMatches, .includeNonPrefixedMatches])
            }
        }

        if let publicKey = PublicKey(hex: metadataEvent.pubkey) {
            _ = pubkeyTrie.insert(key: publicKey.npub, value: metadataEvent.pubkey, options: [.includeNonPrefixedMatches])
        }
    }

    private func didReceiveTimeBasedCalendarEvent(_ timeBasedCalendarEvent: TimeBasedCalendarEvent) {
        guard let eventCoordinates = timeBasedCalendarEvent.replaceableEventCoordinates()?.tag.value,
              let startTimestamp = timeBasedCalendarEvent.startTimestamp,
              startTimestamp <= timeBasedCalendarEvent.endTimestamp ?? startTimestamp,
              startTimestamp.timeIntervalSince1970 > 0 else {
            return
        }

        let existingEvent = self.timeBasedCalendarEvents[eventCoordinates]
        if let existingEvent, existingEvent.createdAt >= timeBasedCalendarEvent.createdAt {
            return
        }

        timeBasedCalendarEvents[eventCoordinates] = timeBasedCalendarEvent

        updateEventsTrie(oldEvent: existingEvent, newEvent: timeBasedCalendarEvent)
    }

    func updateEventsTrie(oldEvent: TimeBasedCalendarEvent? = nil, newEvent: TimeBasedCalendarEvent) {
        guard let eventCoordinates = newEvent.replaceableEventCoordinates()?.tag.value else {
            return
        }

        if let oldEvent, oldEvent.createdAt >= newEvent.createdAt {
            return
        }

        let newTitle = newEvent.title?.trimmedOrNilIfEmpty
        let newSummary = newEvent.summary?.trimmedOrNilIfEmpty
        let newLocations = OrderedSet(newEvent.locations.compactMap { $0.trimmedOrNilIfEmpty })
        let newHashtags = OrderedSet(newEvent.hashtags.compactMap { $0.trimmedOrNilIfEmpty })

        if let oldEvent {
//            eventsTrie.remove(key: oldEvent.id, value: eventCoordinates)
            if let title = oldEvent.title?.trimmedOrNilIfEmpty, title != newTitle {
                eventsTrie.remove(key: title, value: eventCoordinates)
            }
            let locationsToRemove = OrderedSet(oldEvent.locations.compactMap { $0.trimmedOrNilIfEmpty }).subtracting(newLocations)
            locationsToRemove.forEach { location in
                eventsTrie.remove(key: location, value: eventCoordinates)
            }
            let hashtagsToRemove = OrderedSet(oldEvent.hashtags.compactMap { $0.trimmedOrNilIfEmpty }).subtracting(newHashtags)
            hashtagsToRemove.forEach { hashtag in
                eventsTrie.remove(key: hashtag, value: eventCoordinates)
            }
        }

        _ = eventsTrie.insert(key: newEvent.id, value: eventCoordinates)
        _ = eventsTrie.insert(key: newEvent.pubkey, value: eventCoordinates)
        if let authorPublicKey = PublicKey(hex: newEvent.pubkey) {
            _ = eventsTrie.insert(key: authorPublicKey.npub, value: eventCoordinates)
        }
        if let identifier = newEvent.identifier {
            _ = eventsTrie.insert(key: identifier, value: eventCoordinates, options: [.includeCaseInsensitiveMatches])
        }
        if let newTitle {
            _ = eventsTrie.insert(key: newTitle, value: eventCoordinates, options: [.includeCaseInsensitiveMatches, .includeDiacriticsInsensitiveMatches, .includeNonPrefixedMatches])
        }
        newLocations.forEach { location in
            _ = eventsTrie.insert(key: location, value: eventCoordinates, options: [.includeCaseInsensitiveMatches, .includeDiacriticsInsensitiveMatches, .includeNonPrefixedMatches])
        }
        newHashtags.forEach { hashtag in
            _ = eventsTrie.insert(key: hashtag, value: eventCoordinates, options: [.includeCaseInsensitiveMatches, .includeDiacriticsInsensitiveMatches])
        }
    }

    private func didReceiveCalendarListEvent(_ calendarListEvent: CalendarListEvent) {
        guard let eventCoordinates = calendarListEvent.replaceableEventCoordinates()?.tag.value else {
            return
        }

        let existingCalendar = self.calendarListEvents[eventCoordinates]
        if let existingCalendar, existingCalendar.createdAt >= calendarListEvent.createdAt {
            return
        }

        calendarListEvents[eventCoordinates] = calendarListEvent

        updateCalendarsTrie(oldCalendar: existingCalendar, newCalendar: calendarListEvent)
    }

    func updateCalendarsTrie(oldCalendar: CalendarListEvent? = nil, newCalendar: CalendarListEvent) {
        guard let eventCoordinates = newCalendar.replaceableEventCoordinates()?.tag.value else {
            return
        }

        if let oldCalendar, oldCalendar.createdAt >= newCalendar.createdAt {
            return
        }

        let newTitle = newCalendar.title?.trimmedOrNilIfEmpty
        let newName = newCalendar.firstValueForRawTagName("name")?.trimmedOrNilIfEmpty

        if let oldCalendar {
            calendarsTrie.remove(key: oldCalendar.id, value: eventCoordinates)
            if let oldTitle = oldCalendar.title?.trimmedOrNilIfEmpty, oldTitle != newTitle {
                calendarsTrie.remove(key: oldTitle, value: eventCoordinates)
            }
            if let oldName = newCalendar.firstValueForRawTagName("name")?.trimmedOrNilIfEmpty, oldName != oldName {
                calendarsTrie.remove(key: oldName, value: eventCoordinates)
            }
        }

        _ = calendarsTrie.insert(key: newCalendar.id, value: eventCoordinates)
        _ = calendarsTrie.insert(key: newCalendar.pubkey, value: eventCoordinates)
        if let identifier = newCalendar.identifier {
            _ = calendarsTrie.insert(key: identifier, value: eventCoordinates)
        }
        if let newTitle {
            _ = calendarsTrie.insert(key: newTitle, value: eventCoordinates, options: [.includeCaseInsensitiveMatches, .includeDiacriticsInsensitiveMatches, .includeNonPrefixedMatches])
        }
        if let newName {
            _ = calendarsTrie.insert(key: newName, value: eventCoordinates, options: [.includeCaseInsensitiveMatches, .includeDiacriticsInsensitiveMatches, .includeNonPrefixedMatches])
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
        // pullMissingEventsFromPubkeysAndFollows([rsvp.pubkey])
    }

    private func deleteFromEventCoordinates(_ deletionEvent: DeletionEvent) {
        let deletedEventCoordinates = deletionEvent.eventCoordinates.filter {
            $0.pubkey?.hex == deletionEvent.pubkey
        }

        for deletedEventCoordinate in deletedEventCoordinates {
            if let existingDeletedEventCoordinateDate = self.deletedEventCoordinates[deletedEventCoordinate.tag.value] {
                if existingDeletedEventCoordinateDate < deletionEvent.createdDate {
                    self.deletedEventCoordinates[deletedEventCoordinate.tag.value] = deletionEvent.createdDate
                } else {
                    continue
                }
            } else {
                self.deletedEventCoordinates[deletedEventCoordinate.tag.value] = deletionEvent.createdDate
            }

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
                case let calendarListEvent as CalendarListEvent:
                    if let eventCoordinates = calendarListEvent.replaceableEventCoordinates()?.tag.value, calendarListEvents[eventCoordinates]?.id == calendarListEvent.id {
                        calendarListEvents.removeValue(forKey: eventCoordinates)
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

    func delete(events: [NostrEvent]) {
        guard let keypair else {
            return
        }

        let deletableEvents = events.filter { $0.pubkey == keypair.publicKey.hex }
        guard !deletableEvents.isEmpty else {
            return
        }

        let replaceableEvents = deletableEvents.compactMap { $0 as? ReplaceableEvent }

        do {
            let deletionEvent = try delete(events: deletableEvents, replaceableEvents: replaceableEvents, signedBy: keypair)
            relayWritePool.publishEvent(deletionEvent)
            _ = didReceive(nostrEvent: deletionEvent)
        } catch {
            print("Unable to delete NostrEvents. [\(events.map { "{ id=\($0.id), kind=\($0.kind)}" }.joined(separator: ", "))]")
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

            _ = self.didReceive(nostrEvent: nostrEvent, relay: relay)
        }
    }

    func didReceive(nostrEvent: NostrEvent, relay: Relay? = nil) -> PersistentNostrEvent? {
        switch nostrEvent {
        case let followListEvent as FollowListEvent:
            self.didReceiveFollowListEvent(followListEvent, shouldPullMissingEvents: true)
        case let metadataEvent as MetadataEvent:
            self.didReceiveMetadataEvent(metadataEvent)
        case let timeBasedCalendarEvent as TimeBasedCalendarEvent:
            self.didReceiveTimeBasedCalendarEvent(timeBasedCalendarEvent)
        case let calendarListEvent as CalendarListEvent:
            self.didReceiveCalendarListEvent(calendarListEvent)
        case let rsvpEvent as CalendarEventRSVP:
            self.didReceiveCalendarEventRSVP(rsvpEvent)
        case let deletionEvent as DeletionEvent:
            self.didReceiveDeletionEvent(deletionEvent)
        default:
            return nil
        }

        let persistentNostrEvent: PersistentNostrEvent
        if let existingEvent = self.persistentNostrEvent(nostrEvent.id) {
            if let relay, !existingEvent.relays.contains(where: { $0 == relay.url }) {
                existingEvent.relays.append(relay.url)
            }
            persistentNostrEvent = existingEvent
        } else {
            if let relay {
                persistentNostrEvent = PersistentNostrEvent(nostrEvent: nostrEvent, relays: [relay.url])
            } else {
                persistentNostrEvent = PersistentNostrEvent(nostrEvent: nostrEvent)
            }
            self.modelContext.insert(persistentNostrEvent)
            do {
                try self.modelContext.save()
            } catch {
                print("Failed to save PersistentNostrEvent. id=\(nostrEvent.id)")
            }
        }

        return persistentNostrEvent
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
            case let calendarListEvent as CalendarListEvent:
                self.didReceiveCalendarListEvent(calendarListEvent)
            case let rsvpEvent as CalendarEventRSVP:
                self.didReceiveCalendarEventRSVP(rsvpEvent)
            case let deletionEvent as DeletionEvent:
                self.didReceiveDeletionEvent(deletionEvent)
            default:
                break
            }
        }

        if let publicKey, let followListEvent = followListEvents[publicKey.hex] {
            pullMissingEventsFromPubkeysAndFollows(followListEvent.followedPubkeys)
        }
    }

    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        DispatchQueue.main.async {
            switch response {
            case let .eose(subscriptionId):
                // Live new events are not strictly needed for this app for now.
                // In the future, we could keep subscriptions open for updates.
                try? relay.closeSubscription(with: subscriptionId)
                self.updateRelaySubscriptionCounts(closedSubscriptionId: subscriptionId)
            case let .closed(subscriptionId, _):
                self.updateRelaySubscriptionCounts(closedSubscriptionId: subscriptionId)
            case let .ok(eventId, success, message):
                if success {
                    if let persistentNostrEvent = self.persistentNostrEvent(eventId), !persistentNostrEvent.relays.contains(relay.url) {
                        persistentNostrEvent.relays.append(relay.url)
                    }
                } else if message.prefix == .rateLimited {
                    // TODO retry with exponential backoff.
                }
            default:
                break
            }
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
                pullMissingEventsFromPubkeysAndFollows(timeBasedCalendarEvents.values.map { $0.pubkey })
            } else {
                timeBasedCalendarEventSubscriptionCounts[closedSubscriptionId] = timeBasedCalendarEventSubscriptionCount - 1
            }
        }
    }

}

enum HomeTabs {
    case events
    case calendars
}
