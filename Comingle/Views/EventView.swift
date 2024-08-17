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

struct EventView: View, EventCreating {

    @EnvironmentObject var appState: AppState
    let eventCoordinates: EventCoordinates

    @State var showLocationAlert: Bool = false
    @State var selectedGeohash: Bool = false
    @State var selectedLocation: String = ""

    @State var isContentTranslationPresented: Bool = false
    @State var contentTranslationReplaced: Bool = false
    @State var contentTextTranslation: String = ""

    @State var isChangingRSVP: Bool = false

    @State var isShowingEventRetractionConfirmation: Bool = false

    let rsvpSortComparator: RSVPSortComparator
    let calendarEventParticipantSortComparator: CalendarEventParticipantSortComparator

    init(appState: AppState, event: TimeBasedCalendarEvent) {
        eventCoordinates = event.replaceableEventCoordinates()!
        rsvpSortComparator = RSVPSortComparator(order: .forward, appState: appState)
        calendarEventParticipantSortComparator = CalendarEventParticipantSortComparator(order: .forward, appState: appState)
    }

    var event: TimeBasedCalendarEvent? {
        appState.timeBasedCalendarEvents[eventCoordinates.tag.value]
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

    var summary: String? {
        event?.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var contentText: String {
        if contentTranslationReplaced {
            contentTextTranslation
        } else {
            event?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    var geohash: Geohash? {
        if let geohashString = event?.geohash?.trimmedOrNilIfEmpty, !geohashString.isEmpty {
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

    var timeZonePreference: TimeZonePreference {
        appState.appearanceSettings?.timeZonePreference ?? .event
    }

    var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("EdMMMyyyyhmmz")
        let calendar = Calendar.autoupdatingCurrent
        switch timeZonePreference {
        case .event:
            dateFormatter.timeZone = event?.startTimeZone ?? calendar.timeZone
        case .system:
            dateFormatter.timeZone = calendar.timeZone
        }
        return dateFormatter
    }

    var dateIntervalFormatter: DateIntervalFormatter {
        let dateIntervalFormatter = DateIntervalFormatter()
        dateIntervalFormatter.dateTemplate = "EdMMMyyyyhmmz"
        let calendar = Calendar.autoupdatingCurrent
        switch timeZonePreference {
        case .event:
            dateIntervalFormatter.timeZone = event?.startTimeZone ?? calendar.timeZone
        case .system:
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

            appState.relayWritePool.publishEvent(createdRSVP)

            if let rsvpEventCoordinates = createdRSVP.replaceableEventCoordinates()?.tag.value {
                appState.updateCalendarEventRSVP(createdRSVP, rsvpEventCoordinates: rsvpEventCoordinates)
            }
        }
    }

    func retractRSVP() {
        guard let keypair = appState.keypair else {
            return
        }

        let calendarEventCoordinates = eventCoordinates.tag.value
        let publicKeyHex = keypair.publicKey.hex

        if let rsvps = appState.calendarEventsToRsvps[calendarEventCoordinates]?.filter({ $0.pubkey == publicKeyHex }),
           !rsvps.isEmpty {
            appState.delete(events: rsvps)
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

    var contentView: some View {
        VStack {
            if let summary {
                Text(.localizable.eventSummary)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(.init(summary))
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
            }

            if contentTranslationReplaced {
                Text(.localizable.aboutTranslated)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(.localizable.about)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if #available(iOS 17.4, macOS 14.4, *), contentTranslationReplaced || shouldAllowTranslation(contentText) {
                Text(.init(contentText))
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .translationPresentation(isPresented: $isContentTranslationPresented, text: contentText) { translatedString in
                        contentTextTranslation = translatedString
                        contentTranslationReplaced = true
                    }
                    .onTapGesture {
                        if contentTranslationReplaced {
                            contentTranslationReplaced = false
                        } else {
                            isContentTranslationPresented = true
                        }
                    }
                    .onLongPressGesture {
                        if contentTranslationReplaced {
                            contentTranslationReplaced = false
                        } else {
                            isContentTranslationPresented = true
                        }
                    }
            } else {
                Text(.init(contentText))
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    var referencesView: some View {
        VStack {
            if let references = event?.references, !references.isEmpty {
                Text(.localizable.links)
                    .font(.headline)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(references, id: \.self) { reference in
                    Text(.init(reference.absoluteString))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                EmptyView()
            }
        }
    }

    var locationsView: some View {
        ForEach(filteredLocations, id: \.self) { location in
            Divider()

            Button(action: {
                selectedLocation = location
                selectedGeohash = false
                showLocationAlert = true
            }, label: {
                Text(location)
            })
        }
    }

    var profileView: some View {
        NavigationLink(
            destination: {
                if let event {
                    ProfileView(publicKeyHex: event.pubkey)
                }
            },
            label: {
                if let event {
                    ProfilePictureAndNameView(publicKeyHex: event.pubkey)
                }
            }
        )
    }

    var participantsView: some View {
        VStack(alignment: .leading) {
            if let event {
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

                                        if appState.followedPubkeys.contains(publicKeyHex) {
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
                   let rsvps = appState.calendarEventsToRsvps[calendarEventCoordinates] {
                    Divider()

                    Text(.localizable.rsvps(rsvps.count))
                        .padding(.vertical, 2)
                        .font(.headline)

                    ForEach(rsvps.sorted(using: rsvpSortComparator), id: \.self) { rsvp in
                        HStack {
                            NavigationLink(
                                destination: {
                                    ProfileView(publicKeyHex: rsvp.pubkey)
                                },
                                label: {
                                    HStack {
                                        ImageOverlayView(
                                            imageSystemName: rsvpStatusSystemImage(rsvp.status),
                                            overlayBackgroundColor: rsvpStatusColor(rsvp.status)
                                        ) {
                                            ProfilePictureView(publicKeyHex: rsvp.pubkey)
                                        }

                                        VStack(alignment: .leading) {
                                            ProfileNameView(publicKeyHex: rsvp.pubkey)

                                            if appState.followedPubkeys.contains(rsvp.pubkey) {
                                                Image(systemName: "figure.stand.line.dotted.figure.stand")
                                                    .font(.footnote)
                                            }
                                        }
                                    }
                                }
                            )

                            let persistentRSVP = appState.persistentNostrEvent(rsvp.id)
                            if ((persistentRSVP?.relays.isEmpty) != false) {
                                Button(action: {
                                    appState.relayWritePool.publishEvent(rsvp)
                                }, label: {
                                    Image(systemName: "exclamationmark.arrow.circlepath")
                                })
                            }
                        }
                    }
                }
            }
        }
    }

    var calendar: Calendar {
        if let startTimeZone = event?.startTimeZone, timeZonePreference == .event {
            var calendar = Calendar(identifier: .iso8601)
            calendar.timeZone = startTimeZone
            return calendar
        } else {
            return Calendar.autoupdatingCurrent
        }
    }

    @ViewBuilder func changeRSVPConfirmationDialogActions() -> some View {
        if let event {
            Button(action: {
                createOrUpdateRSVP(.accepted)
            }, label: {
                if event.isUpcoming {
                    Text(.localizable.rsvpStatusGoing)
                } else {
                    Text(.localizable.attended)
                }
            })

            Button(action: {
                createOrUpdateRSVP(.tentative)
            }, label: {
                if event.isUpcoming {
                    Text(.localizable.rsvpStatusMaybeGoing)
                } else {
                    Text(.localizable.maybeAttended)
                }
            })

            Button(action: {
                createOrUpdateRSVP(.declined)
            }, label: {
                if event.isUpcoming {
                    Text(.localizable.rsvpStatusNotGoing)
                } else {
                    Text(.localizable.didNotAttend)
                }
            })

            if let keypair = appState.keypair,
               let rsvps = appState.calendarEventsToRsvps[eventCoordinates.tag.value],
               rsvps.contains(where: { $0.pubkey == keypair.publicKey.hex }) {
                Button(
                    role: .destructive,
                    action: {
                        retractRSVP()
                    },
                    label: {
                        Text(.localizable.retractRSVP)
                    }
                )
            }
        }
    }

    @ViewBuilder func locationConfirmationDialogActions() -> some View {
        if selectedGeohash, let geohash = geohash {
            let coordinatesString = "\(geohash.latitude),\(geohash.longitude)"
            let encodedLocation = coordinatesString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? coordinatesString
            Button(action: {
                let encodedTitle = eventTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? eventTitle
                if let url = URL(string: "https://maps.apple.com/?ll=\(encodedLocation)&q=\(encodedTitle)") {
                    UIApplication.shared.open(url)
                }
                selectedGeohash = false
                selectedLocation = ""
            }, label: {
                Text(.localizable.openInAppleMaps)
            })
            Button(action: {
                if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedLocation)") {
                    UIApplication.shared.open(url)
                }
                selectedGeohash = false
                selectedLocation = ""
            }, label: {
                Text(.localizable.openInGoogleMaps)
            })
            Button(action: {
                UIPasteboard.general.string = coordinatesString
                selectedGeohash = false
                selectedLocation = ""
            }, label: {
                Text(.localizable.copyCoordinates)
            })
        } else if !selectedLocation.isEmpty {
            if let selectedLocationURL = URL(string: selectedLocation), selectedLocation.hasPrefix("https://") || selectedLocation.hasPrefix("http://") {
                Button(action: {
                    UIApplication.shared.open(selectedLocationURL)
                    selectedGeohash = false
                    selectedLocation = ""
                }, label: {
                    Text(.localizable.openLink)
                })
            } else {
                let encodedLocation = selectedLocation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? selectedLocation
                Button(action: {
                    if let url = URL(string: "https://maps.apple.com/?q=\(encodedLocation)") {
                        UIApplication.shared.open(url)
                    }
                    selectedGeohash = false
                    selectedLocation = ""
                }, label: {
                    Text(.localizable.openInAppleMaps)
                })
                Button(action: {
                    if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedLocation)") {
                        UIApplication.shared.open(url)
                    }
                    selectedGeohash = false
                    selectedLocation = ""
                }, label: {
                    Text(.localizable.openInGoogleMaps)
                })
            }
            Button(action: {
                UIPasteboard.general.string = selectedLocation
                selectedGeohash = false
                selectedLocation = ""
            }, label: {
                Text(.localizable.copyLocation)
            })
        }
    }

    @ViewBuilder func eventRetractionConfirmationDialogActions() -> some View {
        if let event, appState.keypair?.publicKey.hex == event.pubkey {
            Button(
                role: .destructive,
                action: {
                    appState.delete(events: [event])
                },
                label: {
                    Text(.localizable.retractEvent)
                }
            )
        }
    }

    var body: some View {
        if let event {
            ScrollView {
                VStack {
                    if let calendarEventImageURL = event.imageURL,
                       calendarEventImageURL.isImage {
                        KFImage.url(calendarEventImageURL)
                            .resizable()
                            .placeholder { ProgressView() }
                            .scaledToFit()
                            .frame(maxWidth: 500, maxHeight: 200)
                    }

                    Text(eventTitle)
                        .padding(.vertical, 2)
                        .font(.largeTitle)

                    if let startTimestamp = event.startTimestamp {
                        Divider()

                        if let endTimestamp = event.endTimestamp {
                            if calendar.isDate(startTimestamp, inSameDayAs: endTimestamp) {
                                Text(dateIntervalFormatter.string(from: startTimestamp, to: endTimestamp))
                            } else {
                                let dateFormatter = dateFormatter
                                Text(dateFormatter.string(from: startTimestamp))
                                Text(dateFormatter.string(from: endTimestamp))
                            }
                        } else {
                            Text(dateFormatter.string(from: startTimestamp))
                        }
                    }

                    locationsView

                    Divider()

                    profileView

                    Divider()

                    contentView

                    Divider()

                    referencesView

                    Divider()

                    participantsView

                    if let geohash = geohash {
                        Divider()

                        Map(bounds: MapCameraBounds(centerCoordinateBounds: geohash.region)) {
                            Marker(eventTitle, coordinate: geohash.region.center)
                        }
                        .frame(height: 250)
                        .onTapGesture {
                            selectedLocation = ""
                            selectedGeohash = true
                            showLocationAlert = true
                        }
                    }

                    if let persistentNostrEvent = appState.persistentNostrEvent(event.id) {
                        Divider()

                        VStack {
                            Text(.localizable.relaysCount(persistentNostrEvent.relays.count))
                                .padding(.vertical, 2)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(persistentNostrEvent.relays, id: \.self) { relayURL in
                                Text(relayURL.absoluteString)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    Divider()

                    VStack {
                        Text(.localizable.lastUpdated)
                            .padding(.vertical, 2)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(dateFormatter.string(from: event.createdDate))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(.localizable.rsvp, isPresented: $isChangingRSVP) {
                changeRSVPConfirmationDialogActions()
            }
            .confirmationDialog(.localizable.location, isPresented: $showLocationAlert) {
                locationConfirmationDialogActions()
            }
            .confirmationDialog(
                .localizable.retractEvent,
                isPresented: $isShowingEventRetractionConfirmation
            ) {
                eventRetractionConfirmationDialogActions()
            }
            .toolbar {
                ToolbarItem {
                    Menu {
                        let relays = appState.persistentNostrEvent(event.id)?.relays ?? []
                        let shareableEventCoordinates = try? event.shareableEventCoordinates(relayURLStrings: relays.map { $0.absoluteString })

                        if appState.keypair != nil && appState.publicKey?.hex == event.pubkey {
                            NavigationLink(destination: CreateOrModifyEventView(appState: appState, existingEvent: event)) {
                                Text(.localizable.modifyEvent)
                            }
                        }

                        if let shareableEventCoordinates {
                            Button(action: {
                                UIPasteboard.general.string = shareableEventCoordinates
                            }, label: {
                                Text(.localizable.copyEventID)
                            })

                            Button(action: {
                                UIPasteboard.general.string = "https://njump.me/\(shareableEventCoordinates)"
                            }, label: {
                                Text(.localizable.copyEventURL)
                            })
                        }

                        Button(action: {
                            var stringToCopy = "\(eventTitle)\n\(dateIntervalFormatter.string(from: event.startTimestamp!, to: event.endTimestamp!))\n\n\(filteredLocations.joined(separator: "\n"))\n\n\(contentText)\n\n"

                            let metadataEvent = appState.metadataEvents[event.pubkey]
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

                        if let keypair = appState.keypair, keypair.publicKey.hex == event.pubkey {
                            Button(
                                role: .destructive,
                                action: {
                                    isShowingEventRetractionConfirmation = true
                                },
                                label: {
                                    Text(.localizable.retractEvent)
                                }
                            )
                        }
                    } label: {
                        Label(.localizable.menu, systemImage: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    if appState.keypair == nil {
                        NavigationLink(
                            destination: SettingsView(appState: appState),
                            label: {
                                Text(.localizable.signInToRSVP)
                            }
                        )
                    } else {
                        Button(action: {
                            isChangingRSVP = true
                        }, label: {
                            if let currentUserRSVP {
                                if event.isUpcoming {
                                    switch currentUserRSVP.status {
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
                                    switch currentUserRSVP.status {
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
                refresh()
            }
            .refreshable {
                refresh()
            }
        } else {
            Text(.localizable.eventNotFound)
        }
    }

    func refresh() {
        let until = Date.now

        if let event {
            let calendarEventCoordinates = eventCoordinates.tag.value
            guard let eventFilter = Filter(
                authors: [event.pubkey],
                kinds: [EventKind.timeBasedCalendarEvent.rawValue],
                tags: ["d": [calendarEventCoordinates]],
                since: Int(event.createdAt),
                until: Int(until.timeIntervalSince1970)
            ) else {
                print("Unable to create time-based calendar event filter.")
                return
            }
            _ = appState.relayReadPool.subscribe(with: eventFilter)

            var pubkeysToPullMetadata = [event.pubkey] + event.participants.compactMap { $0.pubkey?.hex }
            if let calendarEventCoordinates = event.replaceableEventCoordinates()?.tag.value,
               let rsvps = appState.calendarEventsToRsvps[calendarEventCoordinates] {
                pubkeysToPullMetadata += rsvps.map { $0.pubkey }
            }
            appState.pullMissingEventsFromPubkeysAndFollows(pubkeysToPullMetadata)

            guard let rsvpFilter = Filter(
                kinds: [EventKind.calendarEventRSVP.rawValue],
                tags: ["a": [calendarEventCoordinates]],
                until: Int(until.timeIntervalSince1970)
            )
            else {
                print("Unable to create calendar event RSVP filter.")
                return
            }
            _ = appState.relayReadPool.subscribe(with: rsvpFilter)
        }
    }
}

//struct EventView_Previews: PreviewProvider {
//    static var previews: some View {
//        EventView(event: TimeBasedCalendarEvent(content: "description", signedBy: Keypair()!), calendar: Calendar.autoupdatingCurrent)
//    }
//}
