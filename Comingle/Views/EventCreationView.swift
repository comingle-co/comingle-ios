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
                    Toggle("Set Time Zone", isOn: $viewModel.isSettingTimeZone)

                    if viewModel.isSettingTimeZone {
                        Button(action: {
                            viewModel.isShowingTimeZoneSelector = true
                        }, label: {
                            Text(viewModel.timeZone?.displayName(for: viewModel.start) ?? "")
                        })
                    }
                } footer: {
                    Text("Enter a time zone if this is primarily an in-person event.")
                }

                Section {

                } header: {
                    Text("Participants")
                }

                Section {
                    TextEditor(text: $viewModel.description)
                } header: {
                    Text("Event description")
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
                let event = try timeBasedCalendarEvent(
                    title: trimmedTitle,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTimestamp: start,
                    endTimestamp: end,
                    startTimeZone: timeZone,
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
