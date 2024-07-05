//
//  SessionView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import GeohashKit
import Kingfisher
import NostrSDK
import NaturalLanguage
import SwiftUI
import Translation

struct SessionView: View {

    private let dateIntervalFormatter = DateIntervalFormatter()
    private let session: TimeBasedCalendarEvent
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

    init(session: TimeBasedCalendarEvent, calendar: Calendar) {
        self.session = session
        self.calendar = calendar

        let timeZone = session.startTimeZone ?? calendar.timeZone

        dateIntervalFormatter.dateTemplate = "EdMMMyyyyhmmz"
        dateIntervalFormatter.timeZone = timeZone

        if let geohashString = session.geohash {
            geohash = Geohash(geohash: geohashString)
        } else {
            geohash = nil
        }

        if let eventTitle = session.title?.trimmingCharacters(in: .whitespacesAndNewlines), !eventTitle.isEmpty {
            self.eventTitle = eventTitle
        } else if let eventTitle = session.firstValueForRawTagName("name")?.trimmingCharacters(in: .whitespacesAndNewlines), !eventTitle.isEmpty {
            self.eventTitle = eventTitle
        } else {
            self.eventTitle = String(localized: .localizable.unnamedEvent)
        }

        contentText = session.content.trimmingCharacters(in: .whitespacesAndNewlines)

        filteredLocations = session.locations
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func missingProfilePictureSmallView(_ rsvpStatus: CalendarEventRSVPStatus?) -> some View {
        Image(systemName: "person.crop.circle.fill")
            .aspectRatio(contentMode: .fill)
            .frame(width: 40, height: 40)
            .clipShape(.circle)
            .overlay(
                rsvpStatusView(rsvpStatus)
                    .offset(x: 4, y: 4),
                alignment: .bottomTrailing
            )
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
        default:
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

    var body: some View {
        ScrollView {
            VStack {
                if let calendarEventImage = session.firstValueForRawTagName("image"), let calendarEventImageURL = URL(string: calendarEventImage), calendarEventImageURL.isImage {
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

                Text(dateIntervalFormatter.string(from: session.startTimestamp!, to: session.endTimestamp!))

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

                if let geohash {
                    Divider()

                    Button(action: {
                        selectedLocation = ""
                        selectedGeohash = true
                        showLocationAlert = true
                    }, label: {
                        Text("\(geohash.latitude), \(geohash.longitude)")
                    })
                }

                Divider()

                HStack {
                    let metadataEvent = appState.metadataEvents[session.pubkey]

                    if let pictureURL = metadataEvent?.userMetadata?.pictureURL {
                        KFImage.url(pictureURL)
                            .resizable()
                            .placeholder { ProgressView() }
                            .scaledToFit()
                            .frame(width: 100)
                    }

                    if let publicKey = PublicKey(hex: session.pubkey) {
                        if let nostrURI = URL(string: "nostr:\(publicKey.npub)") {
                            Link(metadataEvent?.resolvedName ?? publicKey.npub, destination: nostrURI)
                        } else {
                            Text(metadataEvent?.resolvedName ?? publicKey.npub)
                        }
                    } else {
                        Text(metadataEvent?.resolvedName ?? session.pubkey)
                    }
                }

                Divider()

                if contentTranslationReplaced {
                    Text(.localizable.aboutTranslated)
                        .font(.headline)
                } else {
                    Text(.localizable.about)
                        .font(.headline)
                }

                if #available(iOS 17.4, macOS 14.4, *), contentTranslationReplaced || shouldAllowTranslation(contentText) {
                    Text(contentText)
                        .padding(.vertical, 2)
                        .font(.subheadline)
                        .translationPresentation(isPresented: $isContentTranslationPresented, text: contentText) { translatedString in
                            contentText = translatedString
                            contentTranslationReplaced = true
                        }
                        .onTapGesture {
                            if contentTranslationReplaced {
                                contentText = session.content.trimmingCharacters(in: .whitespacesAndNewlines)
                                contentTranslationReplaced = false
                            } else {
                                isContentTranslationPresented = true
                            }
                        }
                        .onLongPressGesture {
                            if contentTranslationReplaced {
                                contentText = session.content.trimmingCharacters(in: .whitespacesAndNewlines)
                                contentTranslationReplaced = false
                            } else {
                                isContentTranslationPresented = true
                            }
                        }
                } else {
                    Text(contentText)
                        .padding(.vertical, 2)
                        .font(.subheadline)
                }

                Divider()

                Text(.localizable.invited(session.participants.count))
                    .padding(.vertical, 2)
                    .font(.headline)

                ForEach(session.participants, id: \.self) { participant in
                    Divider()
                    HStack {
                        if let publicKey = participant.pubkey {
                            if let metadataEvent = appState.metadataEvents[publicKey.hex] {
                                if let pictureURL = metadataEvent.userMetadata?.pictureURL {
                                    KFImage.url(pictureURL)
                                        .resizable()
                                        .placeholder { ProgressView() }
                                        .scaledToFit()
                                        .frame(width: 40)
                                        .clipShape(.circle)
                                }

                                VStack {
                                    if let nostrURI = URL(string: "nostr:\(publicKey.npub)") {
                                        Link(metadataEvent.resolvedName, destination: nostrURI)
                                    } else {
                                        Text(metadataEvent.resolvedName)
                                    }

                                    if let role = participant.role?.trimmingCharacters(in: .whitespacesAndNewlines), !role.isEmpty {
                                        Text(role)
                                            .font(.footnote)
                                    }
                                }
                            }
                        } else {
                            Text("No npub")
                        }
                    }
                }

                if let calendarEventCoordinates = session.replaceableEventCoordinates()?.tag.value, let rsvps = appState.calendarEventsToRsvps[calendarEventCoordinates] {
                    Divider()

                    Text(.localizable.rsvps(rsvps.count))
                        .padding(.vertical, 2)
                        .font(.headline)

                    ForEach(rsvps, id: \.self) { rsvp in
                        if let metadataEvent = appState.metadataEvents[rsvp.pubkey] {
                            HStack {
                                if let pictureURL = metadataEvent.userMetadata?.pictureURL {
                                    KFImage.url(pictureURL)
                                        .resizable()
                                        .placeholder { ProgressView() }
                                        .scaledToFit()
                                        .frame(width: 40)
                                        .clipShape(.circle)
                                        .overlay(
                                            rsvpStatusView(rsvp.status)
                                                .offset(x: 4, y: 4),
                                            alignment: .bottomTrailing
                                        )
                                } else {
                                    missingProfilePictureSmallView(rsvp.status)
                                }

                                if let publicKey = PublicKey(hex: rsvp.pubkey) {
                                    if let nostrURI = URL(string: "nostr:\(publicKey.npub)") {
                                        Link(metadataEvent.resolvedName, destination: nostrURI)
                                    } else {
                                        Text(metadataEvent.resolvedName)
                                    }
                                } else {
                                    Text(rsvp.pubkey)
                                }
                            }
                        } else {
                            if let publicKey = PublicKey(hex: rsvp.pubkey) {
                                if let nostrURI = URL(string: "nostr:\(publicKey.npub)") {
                                    Link(publicKey.npub, destination: nostrURI)
                                } else {
                                    Text(publicKey.npub)
                                }
                            } else {
                                Text(rsvp.pubkey)
                            }
                        }
                    }
                }
            }
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
                        Text(.localizable.copyLocation)
                    })
                } else if !selectedLocation.isEmpty {
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
                        let shareableEventCoordinates = try? session.shareableEventCoordinates()
                        Button(action: {
                            var stringToCopy = "\(eventTitle)\n\(dateIntervalFormatter.string(from: session.startTimestamp!, to: session.endTimestamp!))\n\n\(filteredLocations.joined(separator: "\n"))\n\n\(session.content.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"

                            let metadataEvent = appState.metadataEvents[session.pubkey]
                            if let publicKey = PublicKey(hex: session.pubkey) {
                                stringToCopy += String(localized: .localizable.organizer(metadataEvent?.resolvedName ?? publicKey.npub))
                            } else {
                                stringToCopy += String(localized: .localizable.organizer(metadataEvent?.resolvedName ?? session.pubkey))
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
        }
    }
}

//struct SessionView_Previews: PreviewProvider {
//    static var previews: some View {
//        SessionView(session: TimeBasedCalendarEvent(content: "description", signedBy: Keypair()!), calendar: Calendar.current)
//    }
//}
