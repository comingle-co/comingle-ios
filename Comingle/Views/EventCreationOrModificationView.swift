//
//  EventCreationOrModificationView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/29/24.
//

import GeohashKit
import Kingfisher
import MapKit
import NostrSDK
import OrderedCollections
import SwiftData
import SwiftUI

struct EventCreationOrModificationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ViewModel

    init(appState: AppState, existingEvent: TimeBasedCalendarEvent? = nil) {
        let viewModel = ViewModel(appState: appState, existingEvent: existingEvent)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        if viewModel.appState.keypair != nil && (viewModel.existingEvent == nil || viewModel.appState.publicKey?.hex == viewModel.existingEvent?.pubkey) {
            Form {
                Section {
                    TextField(localized: .localizable.eventTitle, text: $viewModel.title)
                } header: {
                    Text(.localizable.eventTitle)
                }

                Section {
                    TextField(localized: .localizable.eventSummary, text: $viewModel.summary)
                } header: {
                    Text(.localizable.eventSummary)
                }

                Section {
                    TextEditor(text: $viewModel.description)
                } header: {
                    Text(.localizable.eventDescription)
                }

                Section {
                    TextField(localized: .localizable.exampleImage, text: $viewModel.imageString)

                    if let validatedImageURL = viewModel.validatedImageURL {
                        KFImage.url(viewModel.validatedImageURL)
                            .resizable()
                            .placeholder { ProgressView() }
                            .scaledToFit()
                            .frame(maxWidth: 100, maxHeight: 200)
                    }
                } header: {
                    Text(.localizable.image)
                }

                Section {
                    Button(action: {
                        viewModel.isShowingLocationSelector = true
                    }, label: {
                        let trimmedLocation = viewModel.location.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedLocation.isEmpty {
                            Text(.localizable.addALocation)
                        } else {
                            Text(trimmedLocation)
                        }
                    })

                    let trimmedGeohash = viewModel.trimmedGeohash
                    if !trimmedGeohash.isEmpty, let geohash = Geohash(geohash: trimmedGeohash) {
                        Map(bounds: MapCameraBounds(centerCoordinateBounds: geohash.region)) {
                            Marker(viewModel.trimmedTitle, coordinate: geohash.region.center)
                        }
                        .frame(height: 250)
                    }
                } header: {
                    Text(.localizable.location)
                }

                Section {
                    DatePicker(
                        String(localized: .localizable.eventStart),
                        selection: $viewModel.start,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)

                    DatePicker(
                        String(localized: .localizable.eventEnd),
                        selection: $viewModel.end,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)

                    Toggle(.localizable.setTimeZone, isOn: $viewModel.isSettingTimeZone)

                    if viewModel.isSettingTimeZone {
                        let timeZone = viewModel.startTimeZone ?? TimeZone.autoupdatingCurrent
                        Button(action: {
                            viewModel.isShowingTimeZoneSelector = true
                        }, label: {
                            Text(timeZone.displayName(for: viewModel.start))
                        })
                    }
                } header: {
                    Text(.localizable.eventTime)
                } footer: {
                    Text(.localizable.timeZoneFooter)
                }

                Section {
                    Button(action: {
                        viewModel.isShowingParticipantSelector = true
                    }, label: {
                        Text(.localizable.participantsCount(viewModel.participants.count))
                    })
                } header: {
                    Text(.localizable.participants)
                } footer: {
                    Text(.localizable.participantsFooter)
                }

                Section {
                    ForEach(viewModel.references, id: \.self) { reference in
                        Text(reference.absoluteString)
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.references.remove(reference)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                            }
                    }

                    HStack {
                        TextField(localized: .localizable.url, text: $viewModel.referenceToAdd)
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Spacer()

                        Button(
                            action: {
                                if let validatedReferenceURL = viewModel.validatedReferenceURL {
                                    viewModel.references.append(validatedReferenceURL)
                                    viewModel.referenceToAdd = ""
                                }
                            },
                            label: {
                                Image(systemName: "plus.circle")
                            }
                        )
                        .disabled(viewModel.validatedReferenceURL == nil)
                    }
                } header: {
                    Text(.localizable.links)
                }

                Section {
                    Button(
                        role: .destructive,
                        action: {
                            viewModel.reset()
                        },
                        label: {
                            if viewModel.existingEvent != nil {
                                Text(.localizable.restoreOriginalEvent)
                            } else {
                                Text(.localizable.resetAllFields)
                            }
                        }
                    )
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .sheet(isPresented: $viewModel.isShowingLocationSelector) {
                NavigationStack {
                    LocationSearchView(location: $viewModel.location, geohash: $viewModel.geohash)
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $viewModel.isShowingTimeZoneSelector) {
                NavigationStack {
                    TimeZoneSelectionView(date: viewModel.start, timeZone: $viewModel.startTimeZone)
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $viewModel.isShowingParticipantSelector) {
                NavigationStack {
                    ParticipantSearchView(appState: viewModel.appState, participants: $viewModel.participants)
                }
                .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if viewModel.saveEvent() {
                            dismiss()
                        }
                    }, label: {
                        Text(.localizable.save)
                    })
                    .disabled(!viewModel.canSave)
                }
            }
        } else {
            // This view should not be used unless the user is logged in with a private key.
            // Therefore, this EmptyView technically should never be shown.
            EmptyView()
        }
    }
}

class EventCreationParticipant: Equatable, Hashable {
    static func == (lhs: EventCreationParticipant, rhs: EventCreationParticipant) -> Bool {
        lhs.publicKeyHex == rhs.publicKeyHex && lhs.role == rhs.role
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(publicKeyHex)
        hasher.combine(role)
    }

    let publicKeyHex: String
    var relayURL: URL?
    var role: String = ""

    init(publicKeyHex: String, relayURL: URL? = nil, role: String = "") {
        self.publicKeyHex = publicKeyHex
    }
}

extension EventCreationOrModificationView {
    @Observable class ViewModel: EventCreating {
        let appState: AppState

        let existingEvent: TimeBasedCalendarEvent?

        var title: String = ""
        var summary: String = ""
        var imageString: String = ""
        var start: Date = Date.now
        var end: Date = Date.now
        var description: String = ""

        var location: String = ""
        var isShowingLocationSelector: Bool = false
        var geohash: String = ""

        var hashtags = OrderedSet<String>()

        var references = OrderedSet<URL>()
        var referenceToAdd: String = ""

        var isSettingTimeZone: Bool = false
        var startTimeZone: TimeZone?
        var isShowingTimeZoneSelector: Bool = false
        var isShowingParticipantSelector: Bool = false

        var participants = Set<EventCreationParticipant>()

        init(appState: AppState, existingEvent: TimeBasedCalendarEvent?) {
            self.appState = appState
            self.existingEvent = existingEvent
            reset()
        }

        func reset() {
            title = existingEvent?.title ?? ""
            summary = existingEvent?.summary ?? ""
            imageString = existingEvent?.imageURL?.absoluteString ?? ""
            description = existingEvent?.content ?? ""
            let now = Date.now
            start = existingEvent?.startTimestamp ?? now
            end = existingEvent?.endTimestamp ?? existingEvent?.startTimestamp ?? now
            startTimeZone = existingEvent?.startTimeZone

            if existingEvent?.startTimeZone != nil {
                isSettingTimeZone = true
            }

            location = existingEvent?.locations.first ?? ""
            isShowingLocationSelector = false
            geohash = existingEvent?.geohash ?? ""
            hashtags = OrderedSet(existingEvent?.hashtags ?? [])
            references = OrderedSet(existingEvent?.references ?? [])
            referenceToAdd = ""

            startTimeZone = existingEvent?.startTimeZone

            existingEvent?.participants.forEach {
                if let pubkey = $0.pubkey {
                    participants.insert(EventCreationParticipant(publicKeyHex: pubkey.hex, relayURL: $0.relayURL, role: $0.role ?? ""))
                }
            }

            isShowingTimeZoneSelector = false
            isShowingParticipantSelector = false
        }

        var trimmedTitle: String {
            title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var trimmedImageString: String {
            imageString.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var trimmedSummary: String {
            summary.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var trimmedGeohash: String {
            geohash.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var navigationTitle: LocalizedStringResource {
            if existingEvent != nil {
                .localizable.modifyEvent
            } else {
                .localizable.createEvent
            }
        }

        var validatedImageURL: URL? {
            if let url = URL(string: trimmedImageString), url.isImage {
                url
            } else {
                nil
            }
        }

        var validatedReferenceURL: URL? {
            URL(string: referenceToAdd)
        }

        var canSave: Bool {
            appState.keypair != nil && start <= end && !trimmedTitle.isEmpty && validatedImageURL != nil
        }

        func saveEvent() -> Bool {
            guard let keypair = appState.keypair else {
                return false
            }

            do {
                let calendarEventParticipants = participants.compactMap {
                    if let publicKey = PublicKey(hex: $0.publicKeyHex) {
                        let trimmedRole = $0.role.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedRole.isEmpty {
                            return CalendarEventParticipant(pubkey: publicKey)
                        } else {
                            return CalendarEventParticipant(pubkey: publicKey, role: $0.role)
                        }
                    } else {
                        return nil
                    }
                }

                let endOrNil: Date?
                if end == start {
                    endOrNil = nil
                } else {
                    endOrNil = end
                }

                let startTimeZoneOrNil: TimeZone?
                if !isSettingTimeZone {
                    startTimeZoneOrNil = nil
                } else {
                    startTimeZoneOrNil = startTimeZone
                }

                let locationsOrNil: [String]?
                let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLocation.isEmpty {
                    locationsOrNil = nil
                } else {
                    locationsOrNil = [trimmedLocation]
                }

                let hashtagsOrNil: [String]?
                if hashtags.isEmpty {
                    hashtagsOrNil = nil
                } else {
                    hashtagsOrNil = Array(hashtags)
                }

                let referencesOrNil: [URL]?
                if references.isEmpty {
                    referencesOrNil = nil
                } else {
                    referencesOrNil = Array(references)
                }

                let event = try timeBasedCalendarEvent(
                    withIdentifier: existingEvent?.identifier ?? UUID().uuidString,
                    title: trimmedTitle,
                    summary: summary.trimmedOrNilIfEmpty,
                    imageURL: validatedImageURL,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTimestamp: start,
                    endTimestamp: endOrNil,
                    startTimeZone: startTimeZoneOrNil,
                    locations: locationsOrNil,
                    geohash: geohash.trimmedOrNilIfEmpty,
                    participants: calendarEventParticipants,
                    hashtags: hashtagsOrNil,
                    references: referencesOrNil,
                    signedBy: keypair
                )

                if let calendarEventCoordinates = event.replaceableEventCoordinates()?.tag.value {
                    appState.timeBasedCalendarEvents[calendarEventCoordinates] = event

                    let persistentNostrEvent = PersistentNostrEvent(nostrEvent: event)
                    appState.modelContext.insert(persistentNostrEvent)
                    try appState.modelContext.save()

                    appState.relayWritePool.publishEvent(event)

                    return true
                }
            } catch {
                print("Unable to save time based calendar event. \(error)")
            }

            return false
        }
    }
}

//#Preview {
//    EventCreationOrModificationView()
//}
