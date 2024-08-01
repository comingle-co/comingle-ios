//
//  EventView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import GeohashKit
import Kingfisher
import MapKit
import NostrSDK
import NaturalLanguage
import SwiftData
import SwiftUI
import Translation

struct EventView: View {

    @State private var viewModel: ViewModel

    let rsvpSortComparator: RSVPSortComparator
    let calendarEventParticipantSortComparator: CalendarEventParticipantSortComparator

    init(appState: AppState, event: TimeBasedCalendarEvent, calendar: Calendar) {
        let viewModel = ViewModel(appState: appState, eventCoordinates: event.replaceableEventCoordinates()!, calendar: calendar)
        _viewModel = State(initialValue: viewModel)

        rsvpSortComparator = RSVPSortComparator(order: .forward, appState: appState)
        calendarEventParticipantSortComparator = CalendarEventParticipantSortComparator(order: .forward, appState: appState)
    }

    var contentView: some View {
        VStack {
            if viewModel.contentTranslationReplaced {
                Text(.localizable.aboutTranslated)
                    .font(.headline)
            } else {
                Text(.localizable.about)
                    .font(.headline)
            }

            if #available(iOS 17.4, macOS 14.4, *), viewModel.contentTranslationReplaced || viewModel.shouldAllowTranslation(viewModel.contentText) {
                Text(.init(viewModel.contentText))
                    .padding(.vertical, 2)
                    .font(.subheadline)
                    .translationPresentation(isPresented: $viewModel.isContentTranslationPresented, text: viewModel.contentText) { translatedString in
                        viewModel.contentTextTranslation = translatedString
                        viewModel.contentTranslationReplaced = true
                    }
                    .onTapGesture {
                        if viewModel.contentTranslationReplaced {
                            viewModel.contentTranslationReplaced = false
                        } else {
                            viewModel.isContentTranslationPresented = true
                        }
                    }
                    .onLongPressGesture {
                        if viewModel.contentTranslationReplaced {
                            viewModel.contentTranslationReplaced = false
                        } else {
                            viewModel.isContentTranslationPresented = true
                        }
                    }
            } else {
                Text(.init(viewModel.contentText))
                    .padding(.vertical, 2)
                    .font(.subheadline)
            }
        }
    }

    var locationsView: some View {
        ForEach(viewModel.filteredLocations, id: \.self) { location in
            Divider()

            Button(action: {
                viewModel.selectedLocation = location
                viewModel.selectedGeohash = false
                viewModel.showLocationAlert = true
            }, label: {
                Text(location)
            })
        }
    }

    var profileView: some View {
        NavigationLink(
            destination: {
                if let event = viewModel.event {
                    ProfileView(publicKeyHex: event.pubkey)
                }
            },
            label: {
                if let event = viewModel.event {
                    ProfilePictureAndNameView(publicKeyHex: event.pubkey)
                }
            }
        )
    }

    var participantsView: some View {
        VStack(alignment: .leading) {
            if let event = viewModel.event {
                Text(.localizable.invited(event.participants.count))
                    .padding(.vertical, 2)
                    .font(.headline)

                ForEach(event.participants.sorted(using: calendarEventParticipantSortComparator), id: \.self) { participant in
                    if let publicKeyHex = participant.pubkey?.hex {
                        Divider()
                        NavigationLink(
                            destination: {
                                ProfileView(publicKeyHex: publicKeyHex)
                            },
                            label: {
                                HStack {
                                    ProfilePictureView(publicKeyHex: publicKeyHex)

                                    VStack(alignment: .leading) {
                                        ProfileNameView(publicKeyHex: publicKeyHex)

                                        if viewModel.appState.followedPubkeys.contains(publicKeyHex) {
                                            Image(systemName: "figure.stand.line.dotted.figure.stand")
                                                .font(.footnote)
                                        }

                                        if let role = participant.role?.trimmingCharacters(in: .whitespacesAndNewlines), !role.isEmpty {
                                            Text(role)
                                                .font(.footnote)
                                        }
                                    }
                                }
                            }
                        )
                    }
                }

                if let calendarEventCoordinates = event.replaceableEventCoordinates()?.tag.value,
                   let rsvps = viewModel.appState.calendarEventsToRsvps[calendarEventCoordinates] {
                    Divider()

                    Text(.localizable.rsvps(rsvps.count))
                        .padding(.vertical, 2)
                        .font(.headline)

                    ForEach(rsvps.sorted(using: rsvpSortComparator), id: \.self) { rsvp in
                        NavigationLink(
                            destination: {
                                ProfileView(publicKeyHex: rsvp.pubkey)
                            },
                            label: {
                                HStack {
                                    ImageOverlayView(
                                        imageSystemName: viewModel.rsvpStatusSystemImage(rsvp.status),
                                        overlayBackgroundColor: viewModel.rsvpStatusColor(rsvp.status)
                                    ) {
                                        ProfilePictureView(publicKeyHex: rsvp.pubkey)
                                    }

                                    VStack(alignment: .leading) {
                                        ProfileNameView(publicKeyHex: rsvp.pubkey)

                                        if viewModel.appState.followedPubkeys.contains(rsvp.pubkey) {
                                            Image(systemName: "figure.stand.line.dotted.figure.stand")
                                                .font(.footnote)
                                        }
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack {
                if let event = viewModel.event {
                    if let calendarEventImage = event.firstValueForRawTagName("image"),
                       let calendarEventImageURL = URL(string: calendarEventImage),
                       calendarEventImageURL.isImage {
                        KFImage.url(calendarEventImageURL)
                            .resizable()
                            .placeholder { ProgressView() }
                            .scaledToFit()
                            .frame(maxWidth: 500, maxHeight: 200)
                    }

                    Text(viewModel.eventTitle)
                        .padding(.vertical, 2)
                        .font(.largeTitle)

                    Divider()

                    Text(viewModel.dateIntervalFormatter.string(from: event.startTimestamp!, to: event.endTimestamp!))

                    locationsView

                    Divider()

                    profileView

                    Divider()

                    contentView

                    Divider()

                    participantsView

                    if let geohash = viewModel.geohash {
                        Divider()

                        Map(bounds: MapCameraBounds(centerCoordinateBounds: geohash.region)) {
                            Marker(viewModel.eventTitle, coordinate: geohash.region.center)
                        }
                        .frame(height: 250)
                        .onTapGesture {
                            viewModel.selectedLocation = ""
                            viewModel.selectedGeohash = true
                            viewModel.showLocationAlert = true
                        }
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(.localizable.rsvp, isPresented: $viewModel.isChangingRSVP) {
            if let event = viewModel.event {
                Button(action: {
                    viewModel.createOrUpdateRSVP(.accepted)
                }, label: {
                    if event.isUpcoming {
                        Text(.localizable.rsvpStatusGoing)
                    } else {
                        Text(.localizable.attended)
                    }
                })

                Button(action: {
                    viewModel.createOrUpdateRSVP(.tentative)
                }, label: {
                    if event.isUpcoming {
                        Text(.localizable.rsvpStatusMaybeGoing)
                    } else {
                        Text(.localizable.maybeAttended)
                    }
                })

                Button(action: {
                    viewModel.createOrUpdateRSVP(.declined)
                }, label: {
                    if event.isUpcoming {
                        Text(.localizable.rsvpStatusNotGoing)
                    } else {
                        Text(.localizable.didNotAttend)
                    }
                })

                if let keypair = viewModel.appState.keypair,
                   let rsvps = viewModel.appState.calendarEventsToRsvps[viewModel.eventCoordinates.tag.value],
                   rsvps.contains(where: { $0.pubkey == keypair.publicKey.hex }) {
                    Button(
                        role: .destructive,
                        action: {
                            viewModel.removeRSVP()
                        },
                        label: {
                            Text(.localizable.removeRSVP)
                        }
                    )
                }
            }
        }
        .confirmationDialog(.localizable.location, isPresented: $viewModel.showLocationAlert) {
            if viewModel.selectedGeohash, let geohash = viewModel.geohash {
                let coordinatesString = "\(geohash.latitude),\(geohash.longitude)"
                let encodedLocation = coordinatesString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? coordinatesString
                Button(action: {
                    let encodedTitle = viewModel.eventTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? viewModel.eventTitle
                    if let url = URL(string: "https://maps.apple.com/?ll=\(encodedLocation)&q=\(encodedTitle)") {
                        UIApplication.shared.open(url)
                    }
                    viewModel.selectedGeohash = false
                    viewModel.selectedLocation = ""
                }, label: {
                    Text(.localizable.openInAppleMaps)
                })
                Button(action: {
                    if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedLocation)") {
                        UIApplication.shared.open(url)
                    }
                    viewModel.selectedGeohash = false
                    viewModel.selectedLocation = ""
                }, label: {
                    Text(.localizable.openInGoogleMaps)
                })
                Button(action: {
                    UIPasteboard.general.string = coordinatesString
                    viewModel.selectedGeohash = false
                    viewModel.selectedLocation = ""
                }, label: {
                    Text(.localizable.copyCoordinates)
                })
            } else if !viewModel.selectedLocation.isEmpty {
                if let selectedLocationURL = URL(string: viewModel.selectedLocation), viewModel.selectedLocation.hasPrefix("https://") || viewModel.selectedLocation.hasPrefix("http://") {
                    Button(action: {
                        UIApplication.shared.open(selectedLocationURL)
                        viewModel.selectedGeohash = false
                        viewModel.selectedLocation = ""
                    }, label: {
                        Text(.localizable.openLink)
                    })
                } else {
                    let encodedLocation = viewModel.selectedLocation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? viewModel.selectedLocation
                    Button(action: {
                        if let url = URL(string: "https://maps.apple.com/?q=\(encodedLocation)") {
                            UIApplication.shared.open(url)
                        }
                        viewModel.selectedGeohash = false
                        viewModel.selectedLocation = ""
                    }, label: {
                        Text(.localizable.openInAppleMaps)
                    })
                    Button(action: {
                        if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedLocation)") {
                            UIApplication.shared.open(url)
                        }
                        viewModel.selectedGeohash = false
                        viewModel.selectedLocation = ""
                    }, label: {
                        Text(.localizable.openInGoogleMaps)
                    })
                }
                Button(action: {
                    UIPasteboard.general.string = viewModel.selectedLocation
                    viewModel.selectedGeohash = false
                    viewModel.selectedLocation = ""
                }, label: {
                    Text(.localizable.copyLocation)
                })
            }
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    if let event = viewModel.event {
                        let relays = viewModel.appState.persistentNostrEvents[event.id]?.relays ?? []
                        let shareableEventCoordinates = try? event.shareableEventCoordinates(relayURLStrings: relays.map { $0.absoluteString })

                        if viewModel.appState.keypair != nil && (viewModel.event == nil || viewModel.appState.publicKey?.hex == viewModel.event?.pubkey) {
                            NavigationLink(destination: EventCreationOrModificationView(appState: viewModel.appState, existingEvent: event)) {
                                Text(.localizable.modifyEvent)
                            }
                        }

                        Button(action: {
                            var stringToCopy = "\(viewModel.eventTitle)\n\(viewModel.dateIntervalFormatter.string(from: event.startTimestamp!, to: event.endTimestamp!))\n\n\(viewModel.filteredLocations.joined(separator: "\n"))\n\n\(viewModel.contentText)\n\n"

                            let metadataEvent = viewModel.appState.metadataEvents[event.pubkey]
                            if let publicKey = PublicKey(hex: event.pubkey) {
                                stringToCopy += String(localized: .localizable.organizer(metadataEvent?.resolvedName ?? publicKey.npub))
                            } else {
                                stringToCopy += String(localized: .localizable.organizer(metadataEvent?.resolvedName ?? event.pubkey))
                            }

                            if let shareableEventCoordinates {
                                // TODO Change to a Comingle URL once the website is set up.
                                stringToCopy += "\n\nhttps://njump.me/\(shareableEventCoordinates)"
                            }

                            UIPasteboard.general.string = stringToCopy
                        }, label: {
                            Text(.localizable.copyEventDetails)
                        })
                        if let shareableEventCoordinates {
                            Button(action: {
                                UIPasteboard.general.string = shareableEventCoordinates
                            }, label: {
                                Text(.localizable.copyEventID)
                            })
                        }
                    } else {
                        Text(verbatim: "")
                    }
                } label: {
                    Label(.localizable.menu, systemImage: "ellipsis.circle")
                }
            }

            ToolbarItem(placement: .bottomBar) {
                if viewModel.appState.keypair == nil {
                    NavigationLink(destination: LoginView(appState: viewModel.appState)) {
                        Text(.localizable.signInToRSVP)
                    }
                } else {
                    Button(action: {
                        viewModel.isChangingRSVP = true
                    }, label: {
                        if let event = viewModel.event, let rsvp = viewModel.currentUserRSVP {
                            if event.isUpcoming {
                                switch rsvp.status {
                                case .accepted:
                                    Text(.localizable.rsvpStatusGoing)
                                case .declined:
                                    Text(.localizable.rsvpStatusNotGoing)
                                case .tentative:
                                    Text(.localizable.rsvpStatusMaybeGoing)
                                case .unknown(let value):
                                    Text(value)
                                case .none:
                                    Text(.localizable.rsvp)
                                }
                            } else {
                                switch rsvp.status {
                                case .accepted:
                                    Text(.localizable.attended)
                                case .declined:
                                    Text(.localizable.didNotAttend)
                                case .tentative:
                                    Text(.localizable.maybeAttended)
                                case .unknown(let value):
                                    Text(value)
                                case .none:
                                    Text(.localizable.didNotAttend)
                                }
                            }
                        } else {
                            Text(.localizable.rsvp)
                        }
                    })
                }
            }
        }
        .task {
            var pubkeysToPullMetadata = viewModel.event?.participants.compactMap { $0.pubkey?.hex } ?? []

            if let rsvps = viewModel.appState.calendarEventsToRsvps[viewModel.eventCoordinates.tag.value] {
                pubkeysToPullMetadata += rsvps.map { $0.pubkey }
            }

            viewModel.appState.pullMissingMetadata(pubkeysToPullMetadata)
        }
        .refreshable {
            if let event = viewModel.event {
                let calendarEventCoordinates = viewModel.eventCoordinates.tag.value
                guard let eventFilter = Filter(
                    authors: [event.pubkey],
                    kinds: [EventKind.timeBasedCalendarEvent.rawValue],
                    tags: ["d": [calendarEventCoordinates]],
                    since: Int(event.createdAt)
                ) else {
                    print("Unable to create time-based calendar event filter.")
                    return
                }
                _ = viewModel.appState.relayPool.subscribe(with: eventFilter)

                var pubkeysToPullMetadata = [event.pubkey] + event.participants.compactMap { $0.pubkey?.hex }
                if let calendarEventCoordinates = event.replaceableEventCoordinates()?.tag.value,
                   let rsvps = viewModel.appState.calendarEventsToRsvps[calendarEventCoordinates] {
                    pubkeysToPullMetadata += rsvps.map { $0.pubkey }
                }
                viewModel.appState.pullMissingMetadata(pubkeysToPullMetadata)

                guard let rsvpFilter = Filter(
                    kinds: [EventKind.calendarEventRSVP.rawValue],
                    tags: ["a": [calendarEventCoordinates]])
                else {
                    print("Unable to create calendar event RSVP filter.")
                    return
                }
                _ = viewModel.appState.relayPool.subscribe(with: rsvpFilter)
            }
        }
    }
}

extension EventView {
    @Observable class ViewModel: EventCreating {
        let appState: AppState
        let eventCoordinates: EventCoordinates
        let originalEvent: TimeBasedCalendarEvent?

        let calendar: Calendar

        var showLocationAlert: Bool = false
        var selectedGeohash: Bool = false
        var selectedLocation: String = ""

        var isContentTranslationPresented: Bool = false
        var contentTranslationReplaced: Bool = false
        var contentTextTranslation: String = ""

        var isChangingRSVP: Bool = false

        init(appState: AppState, eventCoordinates: EventCoordinates, calendar: Calendar) {
            self.appState = appState
            self.eventCoordinates = eventCoordinates
            self.calendar = calendar

            originalEvent = appState.timeBasedCalendarEvents[eventCoordinates.tag.value]
        }

        var event: TimeBasedCalendarEvent? {
            let newEvent = appState.timeBasedCalendarEvents[eventCoordinates.tag.value]
            if originalEvent != newEvent {
                return newEvent
            } else {
                return originalEvent
            }
        }

        var eventTitle: String {
            if let eventTitle = event?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !eventTitle.isEmpty {
                return eventTitle
            } else if let eventTitle = event?.firstValueForRawTagName("name")?.trimmingCharacters(in: .whitespacesAndNewlines), !eventTitle.isEmpty {
                return eventTitle
            } else {
                return String(localized: .localizable.unnamedEvent)
            }
        }

        var contentText: String {
            if contentTranslationReplaced {
                contentTextTranslation
            } else {
                event?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
        }

        var geohash: Geohash? {
            if let geohashString = event?.geohash {
                return Geohash(geohash: geohashString)
            } else {
                return nil
            }
        }

        var filteredLocations: [String] {
            event?.locations
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []
        }

        func shouldAllowTranslation(_ string: String) -> Bool {
            let languageRecognizer = NLLanguageRecognizer()
            languageRecognizer.processString(string)
            guard let locale = languageRecognizer.languageHypotheses(withMaximum: 1).first(where: { $0.value >= 0.5 })?.key.rawValue,
                  let language = localeToLanguage(locale) else {
                return false
            }
            let preferredLanguages = Set(Locale.preferredLanguages.compactMap { localeToLanguage($0) })
            return !preferredLanguages.contains(language)
        }

        func localeToLanguage(_ locale: String) -> String? {
            return Locale.LanguageCode(stringLiteral: locale).identifier(.alpha2)
        }

        var dateIntervalFormatter: DateIntervalFormatter {
            let dateIntervalFormatter = DateIntervalFormatter()
            dateIntervalFormatter.dateTemplate = "EdMMMyyyyhmmz"
            switch appState.appSettings?.activeProfile?.profileSettings?.appearanceSettings?.timeZonePreference {
            case .event:
                dateIntervalFormatter.timeZone = event?.startTimeZone ?? calendar.timeZone
            case .system, .none:
                dateIntervalFormatter.timeZone = calendar.timeZone
            }
            return dateIntervalFormatter
        }

        var currentUserRSVP: CalendarEventRSVP? {
            guard let publicKeyHex = appState.publicKey?.hex else {
                return nil
            }
            return appState.calendarEventsToRsvps[eventCoordinates.tag.value]?.first(where: { $0.pubkey == publicKeyHex })
        }

        func createOrUpdateRSVP(_ status: CalendarEventRSVPStatus) {
            guard let keypair = appState.keypair else {
                return
            }

            let createdRSVP: CalendarEventRSVP?

            if let currentUserRSVP, let rsvpIdentifier = currentUserRSVP.identifier {
                guard currentUserRSVP.status != status else {
                    return
                }

                createdRSVP = try? calendarEventRSVP(withIdentifier: rsvpIdentifier, calendarEventCoordinates: eventCoordinates, status: status, signedBy: keypair)
            } else {
                createdRSVP = try? calendarEventRSVP(calendarEventCoordinates: eventCoordinates, status: status, signedBy: keypair)
            }

            if let createdRSVP {
                let persistentNostrEvent = PersistentNostrEvent(nostrEvent: createdRSVP)
                appState.modelContext.insert(persistentNostrEvent)

                do {
                    try appState.modelContext.save()
                } catch {
                    print("Unable to save RSVP to SwiftData. \(error)")
                }

                appState.relayPool.publishEvent(createdRSVP)

                if let rsvpEventCoordinates = createdRSVP.replaceableEventCoordinates()?.tag.value {
                    appState.updateCalendarEventRSVP(createdRSVP, rsvpEventCoordinates: rsvpEventCoordinates)
                }
            }
        }

        func removeRSVP() {
            guard let keypair = appState.keypair else {
                return
            }

            let calendarEventCoordinates = eventCoordinates.tag.value
            let publicKeyHex = keypair.publicKey.hex

            if let rsvps = appState.calendarEventsToRsvps[calendarEventCoordinates]?.filter({ $0.pubkey == publicKeyHex }),
               !rsvps.isEmpty,
               let deletionEvent = try? delete(events: rsvps, replaceableEvents: rsvps, signedBy: keypair) {

                appState.calendarEventsToRsvps[calendarEventCoordinates]?.removeAll(where: { $0.pubkey == publicKeyHex })
                rsvps.forEach { rsvp in
                    let rsvpId = rsvp.id
                    do {
                        try appState.modelContext.delete(
                            model: PersistentNostrEvent.self,
                            where: #Predicate { persistentNostrEvent in persistentNostrEvent.eventId == rsvpId }
                        )
                    } catch {
                        print("Unable to delete PersistentNostrEvent for calendar event RSVP. id=\(rsvpId) coordinates=\(calendarEventCoordinates) \(error)")
                    }
                }

                let persistentNostrEvent = PersistentNostrEvent(nostrEvent: deletionEvent)
                appState.modelContext.insert(persistentNostrEvent)

                do {
                    try appState.modelContext.save()
                } catch {
                    print("Unable to save RSVP to SwiftData. \(error)")
                }

                appState.relayPool.publishEvent(deletionEvent)
            }

        }

        func rsvpStatusColor(_ rsvpStatus: CalendarEventRSVPStatus?) -> Color {
            guard let rsvpStatus else {
                return .yellow
            }

            switch rsvpStatus {
            case .accepted:
                return .green
            case .declined:
                return .red
            case .tentative, .unknown:
                return .yellow
            }
        }

        func rsvpStatusSystemImage(_ rsvpStatus: CalendarEventRSVPStatus?) -> String {
            guard let rsvpStatus else {
                return "questionmark"
            }

            switch rsvpStatus {
            case .accepted:
                return "checkmark"
            case .declined:
                return "xmark"
            case .tentative, .unknown:
                return "questionmark"
            }
        }
    }
}

//struct EventView_Previews: PreviewProvider {
//    static var previews: some View {
//        EventView(event: TimeBasedCalendarEvent(content: "description", signedBy: Keypair()!), calendar: Calendar.autoupdatingCurrent)
//    }
//}
