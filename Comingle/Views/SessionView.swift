//
//  SessionView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import GeohashKit
import Kingfisher
import NostrSDK
import SwiftUI

struct SessionView: View {

    private let dateIntervalFormatter = DateIntervalFormatter()
    private let session: TimeBasedCalendarEvent
    private let calendar: Calendar

    @State private var showLocationAlert: Bool = false
    @State private var selectedGeohash: Bool = false
    @State private var selectedLocation: String = ""

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

    var body: some View {
        ScrollView {
            VStack {
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

                Text(.localizable.about)
                    .font(.headline)

                Text(session.content)
                    .padding(.vertical, 2)
                    .font(.subheadline)

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

                if let eventIdentifier = session.identifier, let rsvps = appState.calendarEventsToRsvps[eventIdentifier] {
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
//            if let eventIdentifier = session.replaceableEventCoordinates()?.identifier, let rsvps = appState.rsvps[eventIdentifier] {
//                ForEach(rsvps., id: \.self) { participant in
//                    if let pubkey = participant.pubkey {
//                        if let userMetadata = appState.metadataEvents[pubkey.hex]?.userMetadata, let name = userMetadata.name ?? userMetadata.displayName {
//                            Text(name)
//                        } else {
//                            Text(pubkey.npub)
//                        }
//                    } else {
//                        Text("No npub")
//                    }
//                    //                PersonView(person: participant)
//                    //                Link(.localizable.zapWithCommentOrQuestion, destination: URL(string: "lightning:tyiu@tyiu.xyz")!)
//                    Divider()
//                }
//            }
        }
    }
}

//struct SessionView_Previews: PreviewProvider {
//    static var previews: some View {
//        SessionView(session: TimeBasedCalendarEvent(content: "description", signedBy: Keypair()!), calendar: Calendar.current)
//    }
//}
