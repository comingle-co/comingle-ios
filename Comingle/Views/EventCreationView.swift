//
//  EventCreationView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/29/24.
//

import NostrSDK
import SwiftData
import SwiftUI

struct EventCreationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ViewModel

    init(appState: AppState) {
        let viewModel = ViewModel(appState: appState)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        if viewModel.appState.keypair != nil {
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
                            Text(viewModel.timeZone?.displayName(for: viewModel.start) ?? "")
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
                    TextEditor(text: $viewModel.description)
                } header: {
                    Text(.localizable.eventDescription)
                }
            }
            .navigationTitle(.localizable.createEvent)
            .sheet(isPresented: $viewModel.isShowingTimeZoneSelector) {
                TimeZoneSelectionView(date: viewModel.start, timeZone: $viewModel.timeZone)
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
    var role: String = ""

    init(publicKeyHex: String) {
        self.publicKeyHex = publicKeyHex
    }
}

extension EventCreationView {
    @Observable class ViewModel: EventCreating {
        let appState: AppState

        var title: String = ""
        var start: Date = Date()
        var end: Date = Date()
        var description: String = ""

        var isSettingTimeZone: Bool = false
        var timeZone: TimeZone? = TimeZone.autoupdatingCurrent
        var isShowingTimeZoneSelector: Bool = false

        var participants = Set<EventCreationParticipant>()

        init(appState: AppState) {
            self.appState = appState
        }

        var trimmedTitle: String {
            title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canSave: Bool {
            appState.keypair != nil && start <= end && end >= Date.now && !trimmedTitle.isEmpty
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

                let event = try timeBasedCalendarEvent(
                    title: trimmedTitle,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTimestamp: start,
                    endTimestamp: end,
                    startTimeZone: timeZone,
                    participants: calendarEventParticipants,
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
//    EventCreationView()
//}
