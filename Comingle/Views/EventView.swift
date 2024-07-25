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

    init(appState: AppState, event: TimeBasedCalendarEvent, calendar: Calendar) {
        let viewModel = ViewModel(appState: appState, event: event, calendar: calendar)
        _viewModel = State(initialValue: viewModel)
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
                        viewModel.contentText = translatedString
                        viewModel.contentTranslationReplaced = true
                    }
                    .onTapGesture {
                        if viewModel.contentTranslationReplaced {
                            viewModel.contentText = viewModel.event.content.trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.contentTranslationReplaced = false
                        } else {
                            viewModel.isContentTranslationPresented = true
                        }
                    }
                    .onLongPressGesture {
                        if viewModel.contentTranslationReplaced {
                            viewModel.contentText = viewModel.event.content.trimmingCharacters(in: .whitespacesAndNewlines)
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
                ProfileView(publicKeyHex: viewModel.event.pubkey)
            },
            label: {
                ProfilePictureAndNameView(publicKeyHex: viewModel.event.pubkey)
            }
        )
    }

    var participantsView: some View {
        VStack(alignment: .leading) {
            Text(.localizable.invited(viewModel.event.participants.count))
                .padding(.vertical, 2)
                .font(.headline)

            ForEach(viewModel.event.participants, id: \.self) { participant in
                if let publicKeyHex = participant.pubkey?.hex {
                    Divider()
                    NavigationLink(
                        destination: {
                            ProfileView(publicKeyHex: publicKeyHex)
                        },
                        label: {
                            HStack {
                                ProfilePictureView(publicKeyHex: publicKeyHex)

                                VStack {
                                    ProfileNameView(publicKeyHex: publicKeyHex)

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

            if let calendarEventCoordinates = viewModel.event.replaceableEventCoordinates()?.tag.value,
               let rsvps = viewModel.appState.calendarEventsToRsvps[calendarEventCoordinates] {
                Divider()

                Text(.localizable.rsvps(rsvps.count))
                    .padding(.vertical, 2)
                    .font(.headline)

                ForEach(rsvps, id: \.self) { rsvp in
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

                                ProfileNameView(publicKeyHex: rsvp.pubkey)
                            }
                        }
                    )
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack {
                if let calendarEventImage = viewModel.event.firstValueForRawTagName("image"),
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

                Text(viewModel.dateIntervalFormatter.string(from: viewModel.event.startTimestamp!, to: viewModel.event.endTimestamp!))

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
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
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
                    let shareableEventCoordinates = try? viewModel.event.shareableEventCoordinates()
                    Button(action: {
                        var stringToCopy = "\(viewModel.eventTitle)\n\(viewModel.dateIntervalFormatter.string(from: viewModel.event.startTimestamp!, to: viewModel.event.endTimestamp!))\n\n\(viewModel.filteredLocations.joined(separator: "\n"))\n\n\(viewModel.contentText)\n\n"

                        let metadataEvent = viewModel.appState.metadataEvents[viewModel.event.pubkey]
                        if let publicKey = PublicKey(hex: viewModel.event.pubkey) {
                            stringToCopy += String(localized: .localizable.organizer(metadataEvent?.resolvedName ?? publicKey.npub))
                        } else {
                            stringToCopy += String(localized: .localizable.organizer(metadataEvent?.resolvedName ?? viewModel.event.pubkey))
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
                    Button {
                        print()
                    } label: {
                        if let calendarEventCoordinates = viewModel.event.replaceableEventCoordinates()?.tag.value,
                           let rsvps = viewModel.appState.calendarEventsToRsvps[calendarEventCoordinates],
                           let rsvp = rsvps.first(where: { $0.pubkey == viewModel.appState.publicKey?.hex }) {
                            Text(.localizable.changeRSVP)
                        } else {
                            Text(.localizable.rsvp)
                        }
                    }
                }
            }
        }
        .task {
            var pubkeysToPullMetadata = viewModel.event.participants.compactMap { $0.pubkey?.hex }

            if let calendarEventCoordinates = viewModel.event.replaceableEventCoordinates()?.tag.value,
               let rsvps = viewModel.appState.calendarEventsToRsvps[calendarEventCoordinates] {
                pubkeysToPullMetadata += rsvps.map { $0.pubkey }
            }

            viewModel.appState.pullMissingMetadata(pubkeysToPullMetadata)
        }
        .refreshable {
            if let calendarEventCoordinates = viewModel.event.replaceableEventCoordinates()?.tag.value {
                guard let eventFilter = Filter(
                    authors: [viewModel.event.pubkey],
                    kinds: [EventKind.timeBasedCalendarEvent.rawValue],
                    tags: ["d": [calendarEventCoordinates]],
                    since: Int(viewModel.event.createdAt)
                ) else {
                    print("Unable to create time-based calendar event filter.")
                    return
                }
                _ = viewModel.appState.relayPool.subscribe(with: eventFilter)

                var pubkeysToPullMetadata = [viewModel.event.pubkey] + viewModel.event.participants.compactMap { $0.pubkey?.hex }
                if let calendarEventCoordinates = viewModel.event.replaceableEventCoordinates()?.tag.value,
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
    class ViewModel: ObservableObject {
        let appState: AppState
        let event: TimeBasedCalendarEvent

        let calendar: Calendar

        var showLocationAlert: Bool = false
        var selectedGeohash: Bool = false
        var selectedLocation: String = ""

        var isContentTranslationPresented: Bool = false
        var contentText: String
        var contentTranslationReplaced: Bool = false

        let eventTitle: String

        let filteredLocations: [String]

        let geohash: Geohash?

        init(appState: AppState, event: TimeBasedCalendarEvent, calendar: Calendar) {
            self.appState = appState
            self.event = event
            self.calendar = calendar

            if let geohashString = event.geohash {
                geohash = Geohash(geohash: geohashString)
            } else {
                geohash = nil
            }

            if let eventTitle = event.title?.trimmingCharacters(in: .whitespacesAndNewlines), !eventTitle.isEmpty {
                self.eventTitle = eventTitle
            } else if let eventTitle = event.firstValueForRawTagName("name")?.trimmingCharacters(in: .whitespacesAndNewlines), !eventTitle.isEmpty {
                self.eventTitle = eventTitle
            } else {
                self.eventTitle = String(localized: .localizable.unnamedEvent)
            }

            contentText = event.content.trimmingCharacters(in: .whitespacesAndNewlines)

            filteredLocations = event.locations
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
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
                dateIntervalFormatter.timeZone = event.startTimeZone ?? calendar.timeZone
            case .system, .none:
                dateIntervalFormatter.timeZone = calendar.timeZone
            }
            return dateIntervalFormatter
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
//        EventView(event: TimeBasedCalendarEvent(content: "description", signedBy: Keypair()!), calendar: Calendar.current)
//    }
//}
