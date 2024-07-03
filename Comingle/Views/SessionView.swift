//
//  SessionView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import MapKit
import NostrSDK
import OrderedCollections
import SwiftUI

struct SessionView: View {

    private let dateIntervalFormatter = DateIntervalFormatter()
    private let session: TimeBasedCalendarEvent
    private let calendar: Calendar

    @State private var showLocationAlert: Bool = false
    @State private var selectedLocation: String = ""

    @EnvironmentObject private var appState: AppState

    init(session: TimeBasedCalendarEvent, calendar: Calendar) {
        self.session = session
        self.calendar = calendar

        let timeZone = session.startTimeZone ?? calendar.timeZone

        dateIntervalFormatter.dateTemplate = "EdMMMyyyyhmmz"
        dateIntervalFormatter.timeZone = timeZone
    }

    private func missingProfilePictureSmallView(_ rsvpStatus: CalendarEventRSVPStatus?) -> some View {
        Image(systemName: "person.crop.circle.fill")
            .aspectRatio(contentMode: .fill)
            .frame(width: 40, height: 40)
            .clipShape(Circle())
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
                if let title = (session.title ?? session.firstValueForRawTagName("name"))?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    Text(title)
                        .padding(.vertical, 2)
                        .font(.largeTitle)
                } else {
                    Text(.localizable.unnamedEvent)
                        .padding(.vertical, 2)
                        .font(.largeTitle)
                }

                Divider()

                Text(dateIntervalFormatter.string(from: session.startTimestamp!, to: session.endTimestamp!))

                Divider()

                let filteredLocations = session.locations
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                ForEach(filteredLocations, id: \.self) { location in
                    Button(action: {
                        selectedLocation = location
                        showLocationAlert = true
                    }, label: {
                        Text(location)
                    })
                }

                Divider()

                HStack {
                    let metadataEvent = appState.metadataEvents[session.pubkey]

                    if let pictureURL = metadataEvent?.userMetadata?.pictureURL {
                        AsyncImage(url: pictureURL) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 100, height: 100)
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
                    HStack {
                        if let publicKey = participant.pubkey {
                            if let metadataEvent = appState.metadataEvents[publicKey.hex] {
                                if let pictureURL = metadataEvent.userMetadata?.pictureURL {
                                    AsyncImage(url: pictureURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        ProgressView()
                                            .frame(width: 40, height: 40)
                                    }
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
                    Divider()
                }

                if let eventIdentifier = session.identifier, let rsvps = appState.calendarEventsToRsvps[eventIdentifier] {
                    Text(.localizable.rsvps(rsvps.count))
                        .padding(.vertical, 2)
                        .font(.headline)

                    ForEach(rsvps, id: \.self) { rsvp in
                        if let metadataEvent = appState.metadataEvents[rsvp.pubkey] {
                            HStack {
                                if let pictureURL = metadataEvent.userMetadata?.pictureURL {
                                    AsyncImage(url: pictureURL) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                                .overlay(
                                                    rsvpStatusView(rsvp.status)
                                                        .offset(x: 4, y: 4),
                                                    alignment: .bottomTrailing
                                                )
                                        } else if phase.error != nil {
                                            missingProfilePictureSmallView(rsvp.status)
                                        } else {
                                            ProgressView()
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    rsvpStatusView(rsvp.status)
                                                        .offset(x: 4, y: 4),
                                                    alignment: .bottomTrailing
                                                )
                                        }
                                    }
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
                if !selectedLocation.isEmpty {
                    let encodedLocation = selectedLocation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? selectedLocation
                    Button(action: {
                        if let url = URL(string: "https://maps.apple.com/?q=\(encodedLocation)") {
                            UIApplication.shared.open(url)
                        }
                        selectedLocation = ""
                    }, label: {
                        Text(.localizable.openInAppleMaps)
                    })
                    Button(action: {
                        if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedLocation)") {
                            UIApplication.shared.open(url)
                        }
                        selectedLocation = ""
                    }, label: {
                        Text(.localizable.openInGoogleMaps)
                    })
                    Button(action: {
                        UIPasteboard.general.string = selectedLocation
                        selectedLocation = ""
                    }, label: {
                        Text(.localizable.copyLocation)
                    })
                }
            }
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button(action: {
                            UIPasteboard.general.string = session.identifier ?? ""
                        }, label: {
                            Text(.localizable.copyEventID)
                        })
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
