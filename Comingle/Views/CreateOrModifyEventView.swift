//
//  CreateOrModifyEventView.swift
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

struct CreateOrModifyEventView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ViewModel

    init(appState: AppState, existingEvent: TimeBasedCalendarEvent? = nil) {
        let viewModel = ViewModel(appState: appState, existingEvent: existingEvent)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        if viewModel.appState.keypair != nil && (viewModel.existingEvent == nil || viewModel.appState.publicKey?.hex == viewModel.existingEvent?.pubkey) {
            Form {
                let eventTitle = String(localized: "Text indicating that the field is for entering an event title.", comment: "Text indicating that the field is for entering an event title.")
                Section {
                    TextField(eventTitle, text: $viewModel.title)
                } header: {
                    Text(eventTitle)
                }

                let eventSummary = String(localized: "Summary", comment: "Section title for summary section that summarizes the calendar event.")
                Section {
                    TextField(eventSummary, text: $viewModel.summary)
                } header: {
                    Text(eventSummary)
                }

                Section {
                    TextEditor(text: $viewModel.description)
                } header: {
                    Text("Event Description", comment: "Section title for event description.")
                }

                Section {
                    TextField(String(localized: "https://example.com/image.png", comment: "Example image URL of a calendar event image."), text: $viewModel.imageString)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if let validatedImageURL = viewModel.validatedImageURL {
                        KFImage.url(validatedImageURL)
                            .resizable()
                            .placeholder { ProgressView() }
                            .scaledToFit()
                            .frame(maxWidth: 100, maxHeight: 200)
                    }
                } header: {
                    Text("Image", comment: "Section title for image of the event.")
                }

                Section {
                    Button(action: {
                        viewModel.isShowingLocationSelector = true
                    }, label: {
                        let trimmedLocation = viewModel.location.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedLocation.isEmpty {
                            Text("Add a location", comment: "Button to navigate to event location picker sheet.")
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
                    Text("Location", comment: "Confirmation dialog for taking action on the location of a calendar event.")
                }

                Section {
                    DatePicker(
                        String(localized: "Starts", comment: "Text indicating that the form field is for setting the event start date and time."),
                        selection: $viewModel.start,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .environment(\.timeZone, viewModel.startTimeZoneOrCurrent)

                    DatePicker(
                        String(localized: "Ends", comment: "Text indicating that the form field is for setting the event end date and time."),
                        selection: $viewModel.end,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .environment(\.timeZone, viewModel.startTimeZoneOrCurrent)

                    Toggle(String(localized: "Set Time Zone", comment: "Text for toggle for setting time zone on an event."), isOn: $viewModel.isSettingTimeZone)

                    if viewModel.isSettingTimeZone {
                        Button(action: {
                            viewModel.isShowingTimeZoneSelector = true
                        }, label: {
                            Text(viewModel.startTimeZoneOrCurrent.displayName(for: viewModel.start))
                        })
                    }
                } header: {
                    Text("Time", comment: "Section title for the event time section.")
                } footer: {
                    Text("Enter a time zone if this is primarily an in-person event.", comment: "Footer text to explain when a time zone should be entered.")
                }

                Section {
                    Button(action: {
                        viewModel.isShowingParticipantSelector = true
                    }, label: {
                        Text("\(viewModel.participants.count) participants", comment: "Number of invited participants")
                    })
                } header: {
                    Text("Participants", comment: "Section title for participants in event creation view.")
                } footer: {
                    Text("Anyone who is not invited can still RSVP to public events. It is up to you to decide if you want to explicitly invite a participant or who can attend the event.", comment: "Footer text explaining what it means to invite a participant.")
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
                        TextField(String(localized: "URL", comment: "Placeholder text for text field for entering event URL."), text: $viewModel.referenceToAdd)
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
                    Text("Links", comment: "Section title for reference links on an event.")
                }

                Section {
                    Button(
                        role: .destructive,
                        action: {
                            viewModel.reset()
                        },
                        label: {
                            if viewModel.existingEvent != nil {
                                Text("Restore Original Event", comment: "Button to restore event modification fields back to what the original event started with.")
                            } else {
                                Text("Reset All Fields", comment: "Button to reset all fields to the starting point of a fresh event creation.")
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
                        Text("Save", comment: "Button to save a form.")
                    })
                    .disabled(!viewModel.canSave)
                }
            }
        } else {
            // This view should not be used unless the user is signed in with a private key.
            // Therefore, this EmptyView technically should never be shown.
            EmptyView()
        }
    }
}

class EventCreationParticipant: Equatable, Hashable {
    static func == (lhs: EventCreationParticipant, rhs: EventCreationParticipant) -> Bool {
        lhs.publicKeyHex == rhs.publicKeyHex
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(publicKeyHex)
    }

    let publicKeyHex: String
    var relayURL: URL?
    var role: String = ""

    init(publicKeyHex: String, relayURL: URL? = nil, role: String = "") {
        self.publicKeyHex = publicKeyHex
        self.relayURL = relayURL
        self.role = role
    }
}

extension CreateOrModifyEventView {
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

        var startTimeZoneOrCurrent: TimeZone {
            if isSettingTimeZone {
                startTimeZone ?? TimeZone.autoupdatingCurrent
            } else {
                TimeZone.autoupdatingCurrent
            }
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

        var navigationTitle: String {
            if existingEvent != nil {
                String(localized: "Modify Event", comment: "Button to modify event.")
            } else {
                String(localized: "Create an Event", comment: "Navigation title for the view to create an event.")
            }
        }

        var validatedImageURL: URL? {
            guard let url = URL(string: trimmedImageString) else {
                return nil
            }

            return url
        }

        var validatedReferenceURL: URL? {
            URL(string: referenceToAdd)
        }

        var canSave: Bool {
            appState.keypair != nil && start <= end && !trimmedTitle.isEmpty && (trimmedImageString.isEmpty || validatedImageURL != nil)
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
                    startTimeZoneOrNil = startTimeZoneOrCurrent
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

                    appState.updateEventsTrie(oldEvent: existingEvent, newEvent: event)

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
