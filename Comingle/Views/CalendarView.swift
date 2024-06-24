//
//  CalendarView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI
import NostrSDK

struct CalendarView: View {
    @EnvironmentObject var appState: AppState

    private let calendarListEvent: CalendarListEvent
    private let conferenceSessionIds: Set<String>
    private let dateFormatter = DateFormatter()
    private var calendar = Calendar.current

    @State var selectedDayIndex: Int = 0

    init(calendarListEvent: CalendarListEvent) {
        self.calendarListEvent = calendarListEvent
        conferenceSessionIds = Set(calendarListEvent.calendarEventCoordinateList.compactMap { $0.identifier })

//        sessions = appState.timeBasedCalendarEvents

//        calendar.timeZone = conference.timeZone

        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
//        dateFormatter.timeZone = conference.timeZone
    }

    var body: some View {
        TabView {
            ScheduleView(sessions: appState.timeBasedCalendarEvents.values.filter {
                guard let identifier = $0.identifier else {
                    return false
                }
                return conferenceSessionIds.contains(identifier)
            })
            .environmentObject(appState)
            .tabItem {
                Label(.localizable.schedule, systemImage: "calendar")
            }

//            PeopleView(
//                speakers: Array(Set(conference.sessions.flatMap { $0.speakers })),
//                organizers: conference.organizers
//            )
//            .tabItem {
//                Label(.localizable.people, systemImage: "person")
//            }
        }
        .navigationTitle(calendarListEvent.title ?? calendarListEvent.firstValueForRawTagName("name") ?? "Unnamed Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

//struct CalendarView_Previews: PreviewProvider {
//    static var previews: some View {
//        CalendarView(
//            calendarListEvent: try CalendarListEvent(content: "Conference", signedBy: Keypair()!)
//        )
//    }
//}
