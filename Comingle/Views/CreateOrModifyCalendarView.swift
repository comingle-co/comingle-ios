//
//  CreateOrModifyCalendarView.swift
//  Comingle
//
//  Created by Terry Yiu on 8/16/24.
//

import Kingfisher
import NostrSDK
import OrderedCollections
import SwiftUI

struct CreateOrModifyCalendarView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ViewModel

    init(appState: AppState, calendarListEvent: CalendarListEvent? = nil) {
        let viewModel = ViewModel(appState: appState, existingCalendarListEvent: calendarListEvent)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        if viewModel.appState.keypair != nil && (viewModel.existingCalendarListEvent == nil || viewModel.appState.publicKey?.hex == viewModel.existingCalendarListEvent?.pubkey) {
            Form {
                let title = String(localized: "Title", comment: "Text indicating that the field is for entering a calendar title.")
                Section {
                    TextField(title, text: $viewModel.title)
                } header: {
                    Text(title)
                }

                Section {
                    TextEditor(text: $viewModel.description)
                } header: {
                    Text("Calendar Description", comment: "Section title for calendar description.")
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
            }
            .navigationTitle(viewModel.navigationTitle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if viewModel.saveCalendarListEvent() {
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

extension CreateOrModifyCalendarView {
    @Observable class ViewModel: EventCreating {
        let appState: AppState

        let existingCalendarListEvent: CalendarListEvent?

        var title: String = ""
        var description: String = ""
        var imageString: String = ""
        var timeBasedCalendarEventsCoordinates = OrderedSet<EventCoordinates>()

        init(appState: AppState, existingCalendarListEvent: CalendarListEvent?) {
            self.appState = appState
            self.existingCalendarListEvent = existingCalendarListEvent
            reset()
        }

        func reset() {
            title = existingCalendarListEvent?.title ?? ""
            description = existingCalendarListEvent?.content ?? ""
            imageString = existingCalendarListEvent?.imageURL?.absoluteString ?? ""
            timeBasedCalendarEventsCoordinates = OrderedSet(existingCalendarListEvent?.calendarEventCoordinateList ?? [])
        }

        var trimmedTitle: String {
            title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var trimmedDescription: String {
            description.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var trimmedImageString: String {
            imageString.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var validatedImageURL: URL? {
            guard let url = URL(string: trimmedImageString) else {
                return nil
            }

            return url
        }

        var navigationTitle: String {
            if existingCalendarListEvent != nil {
                String(localized: "Modify Calendar", comment: "Button to modify calendar.")
            } else {
                String(localized: "Create a Calendar", comment: "Navigation title for the view to create a calendar.")
            }
        }

        var canSave: Bool {
            appState.keypair != nil && !trimmedTitle.isEmpty && (trimmedImageString.isEmpty || validatedImageURL != nil)
        }

        func saveCalendarListEvent() -> Bool {
            guard let keypair = appState.keypair else {
                return false
            }

            do {
                let calendarListEvent = try calendarListEvent(
                    withIdentifier: existingCalendarListEvent?.identifier ?? UUID().uuidString,
                    title: trimmedTitle,
                    description: trimmedDescription,
                    calendarEventsCoordinates: existingCalendarListEvent?.calendarEventCoordinateList ?? [],
                    imageURL: validatedImageURL,
                    signedBy: keypair
                )

                if let calendarListEventCoordinates = calendarListEvent.replaceableEventCoordinates()?.tag.value {
                    appState.calendarListEvents[calendarListEventCoordinates] = calendarListEvent

                    let persistentNostrEvent = PersistentNostrEvent(nostrEvent: calendarListEvent)
                    appState.modelContext.insert(persistentNostrEvent)
                    try appState.modelContext.save()

                    appState.updateCalendarsTrie(oldCalendar: existingCalendarListEvent, newCalendar: calendarListEvent)

                    appState.relayWritePool.publishEvent(calendarListEvent)

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
//    CreateCalendarView()
//}
