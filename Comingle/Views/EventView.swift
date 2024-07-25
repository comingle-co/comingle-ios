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
import SwiftUI
import Translation

struct EventView: View {

    private let event: TimeBasedCalendarEvent
    private let calendar: Calendar

    @State private var showLocationAlert: Bool = false
    @State private var selectedGeohash: Bool = false
    @State private var selectedLocation: String = ""

    @State private var isContentTranslationPresented: Bool = false
    @State private var contentText: String
    @State private var contentTranslationReplaced: Bool = false

    private let eventTitle: String

    private let filteredLocations: [String]

    private let geohash: Geohash?

    @EnvironmentObject private var appState: AppState

    init(event: TimeBasedCalendarEvent, calendar: Calendar) {
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

    private func rsvpStatusView(_ rsvpStatus: CalendarEventRSVPStatus?) -> some View {
        guard let rsvpStatus else {
            return Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.yellow)
                .frame(width: 16, height: 16)
        }

        return switch rsvpStatus {
        case .accepted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .frame(width: 16, height: 16)
        case .declined:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.red)
                .frame(width: 16, height: 16)
        case .tentative, .unknown:
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.yellow)
                .frame(width: 16, height: 16)
        }
    }

    private func shouldAllowTranslation(_ string: String) -> Bool {
        let languageRecognizer = NLLanguageRecognizer()
        languageRecognizer.processString(string)
        guard let locale = languageRecognizer.languageHypotheses(withMaximum: 1).first(where: { $0.value >= 0.5 })?.key.rawValue,
              let language = localeToLanguage(locale) else {
            return false
        }
        let preferredLanguages = Set(Locale.preferredLanguages.compactMap { localeToLanguage($0) })
        return !preferredLanguages.contains(language)
    }

    private func localeToLanguage(_ locale: String) -> String? {
        return Locale.LanguageCode(stringLiteral: locale).identifier(.alpha2)
    }

    private var dateIntervalFormatter: DateIntervalFormatter {
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

    var body: some View {
        ScrollView {
            VStack {
                if let calendarEventImage = event.firstValueForRawTagName("image"), let calendarEventImageURL = URL(string: calendarEventImage), calendarEventImageURL.isImage {
                    KFImage.url(calendarEventImageURL)
                        .resizable()
                        .placeholder { ProgressView() }
                        .scaledToFit()
                        .frame(maxWidth: 500, maxHeight: 200)
                }

                Text(eventTitle)
                    .padding(.vertical, 2)
                    .font(.largeTitle)

                Divider()

                Text(dateIntervalFormatter.string(from: event.startTimestamp!, to: event.endTimestamp!))

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

                Divider()

                NavigationLink(
                    destination: {
                        ProfileView(publicKeyHex: event.pubkey)
                    },
                    label: {
                        ProfilePictureAndNameView(publicKeyHex: event.pubkey)
                    }
                )

                Divider()

                if contentTranslationReplaced {
                    Text(.localizable.aboutTranslated)
                        .font(.headline)
                } else {
                    Text(.localizable.about)
                        .font(.headline)
                }

                if #available(iOS 17.4, macOS 14.4, *), contentTranslationReplaced || shouldAllowTranslation(contentText) {
                    Text(.init(contentText))
                        .padding(.vertical, 2)
                        .font(.subheadline)
                        .translationPresentation(isPresented: $isContentTranslationPresented, text: contentText) { translatedString in
                            contentText = translatedString
                            contentTranslationReplaced = true
                        }
                        .onTapGesture {
                            if contentTranslationReplaced {
                                contentText = event.content.trimmingCharacters(in: .whitespacesAndNewlines)
                                contentTranslationReplaced = false
                            } else {
                                isContentTranslationPresented = true
                            }
                        }
                        .onLongPressGesture {
                            if contentTranslationReplaced {
                                contentText = event.content.trimmingCharacters(in: .whitespacesAndNewlines)
                                contentTranslationReplaced = false
                            } else {
                                isContentTranslationPresented = true
                            }
                        }
                } else {
                    Text(.init(contentText))
                        .padding(.vertical, 2)
                        .font(.subheadline)
                }

                Divider()

                Text(.localizable.invited(event.participants.count))
                    .padding(.vertical, 2)
                    .font(.headline)

                ForEach(event.participants, id: \.self) { participant in
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

                if let calendarEventCoordinates = event.replaceableEventCoordinates()?.tag.value, let rsvps = appState.calendarEventsToRsvps[calendarEventCoordinates] {
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
                                    ProfilePictureView(publicKeyHex: rsvp.pubkey)
                                        .overlay(
                                            rsvpStatusView(rsvp.status)
                                                .offset(x: 4, y: 4),
                                            alignment: .bottomTrailing
                                        )

                                    ProfileNameView(publicKeyHex: rsvp.pubkey)
                                }
                            }
                        )
                    }
                }

                if let geohash {
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
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(.localizable.location, isPresented: $showLocationAlert) {
            if selectedGeohash, let geohash {
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
        .toolbar {
            ToolbarItem {
                Menu {
                    let shareableEventCoordinates = try? event.shareableEventCoordinates()
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
        }
        .task {
            var pubkeysToPullMetadata = event.participants.compactMap { $0.pubkey?.hex }

            if let calendarEventCoordinates = event.replaceableEventCoordinates()?.tag.value, let rsvps = appState.calendarEventsToRsvps[calendarEventCoordinates] {
                pubkeysToPullMetadata += rsvps.map { $0.pubkey }
            }

            appState.pullMissingMetadata(pubkeysToPullMetadata)
        }
        .refreshable {
            if let calendarEventCoordinates = event.replaceableEventCoordinates()?.tag.value {
                guard let eventFilter = Filter(
                    authors: [event.pubkey],
                    kinds: [EventKind.timeBasedCalendarEvent.rawValue],
                    tags: ["d": [calendarEventCoordinates]],
                    since: Int(event.createdAt)
                ) else {
                    print("Unable to create time-based calendar event filter.")
                    return
                }
                _ = appState.relayPool.subscribe(with: eventFilter)

                var pubkeysToPullMetadata = [event.pubkey] + event.participants.compactMap { $0.pubkey?.hex }
                if let calendarEventCoordinates = event.replaceableEventCoordinates()?.tag.value, let rsvps = appState.calendarEventsToRsvps[calendarEventCoordinates] {
                    pubkeysToPullMetadata += rsvps.map { $0.pubkey }
                }
                appState.pullMissingMetadata(pubkeysToPullMetadata)

                guard let rsvpFilter = Filter(
                    kinds: [EventKind.calendarEventRSVP.rawValue],
                    tags: ["a": [calendarEventCoordinates]])
                else {
                    print("Unable to create calendar event RSVP filter.")
                    return
                }
                _ = appState.relayPool.subscribe(with: rsvpFilter)
            }
        }
    }
}

//struct EventView_Previews: PreviewProvider {
//    static var previews: some View {
//        EventView(event: TimeBasedCalendarEvent(content: "description", signedBy: Keypair()!), calendar: Calendar.current)
//    }
//}
