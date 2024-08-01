//
//  EventCreationOrModificationView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/29/24.
//

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
                }

                Section {
                    Toggle(.localizable.setTimeZone, isOn: $viewModel.isSettingTimeZone)

                    if viewModel.isSettingTimeZone {
                        Button(action: {
                            viewModel.isShowingTimeZoneSelector = true
                        }, label: {
                            Text(viewModel.startTimeZone?.displayName(for: viewModel.start) ?? "")
                        })
                    }
                } footer: {
                    Text(.localizable.timeZoneFooter)
                }

                Section {
                    NavigationLink(destination: ParticipantSearchView(appState: viewModel.appState, participants: $viewModel.participants)) {
                        Text(.localizable.participantsCount(viewModel.participants.count))
                    }
                } header: {
                    Text(.localizable.participants)
                } footer: {
                    Text(.localizable.participantsFooter)
                }

                Section {
                    ForEach(viewModel.references, id: \.self) { reference in
                        HStack {
                            Text(reference.absoluteString)

                            Spacer()

                            Button(
                                action: {
                                    viewModel.references.remove(reference)
                                },
                                label: {
                                    Image(systemName: "minus.circle")
                                }
                            )
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
                }

                Section {
                    TextEditor(text: $viewModel.description)
                } header: {
                    Text(.localizable.eventDescription)
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
            .sheet(isPresented: $viewModel.isShowingTimeZoneSelector) {
                TimeZoneSelectionView(date: viewModel.start, timeZone: $viewModel.startTimeZone)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if viewModel.saveEvent() {
                            dismiss()
                        }
                    }, label: {
                        Text("Save")
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
        var start: Date = Date.now
        var end: Date = Date.now
        var description: String = ""
        var locations: [String] = []
        var geohash: String = ""
        var hashtags: [String] = []
        var references = OrderedSet<URL>()
        var referenceToAdd: String = ""

        var isSettingTimeZone: Bool = false
        var startTimeZone: TimeZone?
        var endTimeZone: TimeZone?
        var isShowingTimeZoneSelector: Bool = false

        var participants = Set<EventCreationParticipant>()

        init(appState: AppState, existingEvent: TimeBasedCalendarEvent?) {
            self.appState = appState
            self.existingEvent = existingEvent
            reset()
        }

        func reset() {
            title = existingEvent?.title ?? ""
            description = existingEvent?.content ?? ""
            let now = Date.now
            start = existingEvent?.startTimestamp ?? now
            end = existingEvent?.endTimestamp ?? existingEvent?.startTimestamp ?? now
            startTimeZone = existingEvent?.startTimeZone
            endTimeZone = existingEvent?.endTimeZone

            if existingEvent?.startTimeZone != nil {
                isSettingTimeZone = true
            }

            locations = existingEvent?.locations ?? []
            geohash = existingEvent?.geohash ?? ""
            hashtags = existingEvent?.hashtags ?? []
            references = OrderedSet(existingEvent?.references ?? [])

            startTimeZone = existingEvent?.startTimeZone
            endTimeZone = existingEvent?.endTimeZone

            existingEvent?.participants.forEach {
                if let pubkey = $0.pubkey {
                    participants.insert(EventCreationParticipant(publicKeyHex: pubkey.hex, relayURL: $0.relayURL, role: $0.role ?? ""))
                }
            }
        }

        var trimmedTitle: String {
            title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var navigationTitle: LocalizedStringResource {
            if existingEvent != nil {
                .localizable.modifyEvent
            } else {
                .localizable.createEvent
            }
        }

        var validatedReferenceURL: URL? {
            URL(string: referenceToAdd)
        }

        var canSave: Bool {
            appState.keypair != nil && start <= end && !trimmedTitle.isEmpty
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

                let endTimeZoneOrNil: TimeZone?
                if !isSettingTimeZone || endTimeZone == startTimeZone {
                    endTimeZoneOrNil = nil
                } else {
                    endTimeZoneOrNil = endTimeZone
                }

                let locationsOrNil: [String]?
                if locations.isEmpty {
                    locationsOrNil = nil
                } else {
                    locationsOrNil = locations
                }

                let geohashOrNil: String?
                if geohash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    geohashOrNil = nil
                } else {
                    geohashOrNil = geohash.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                let hashtagsOrNil: [String]?
                if hashtags.isEmpty {
                    hashtagsOrNil = nil
                } else {
                    hashtagsOrNil = hashtags
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
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTimestamp: start,
                    endTimestamp: endOrNil,
                    startTimeZone: startTimeZoneOrNil,
                    endTimeZone: endTimeZoneOrNil,
                    locations: locationsOrNil,
                    geohash: geohashOrNil,
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

                    appState.relayPool.publishEvent(event)

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
