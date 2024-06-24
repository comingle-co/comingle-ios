//
//  CalendarsView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI
import NostrSDK

struct CalendarsView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            if !appState.calendarListEvents.isEmpty {
                Section(
                    content: {
                        ForEach(appState.calendarListEvents.values.sorted { $0.title ?? $0.firstValueForRawTagName("name") ?? "Unnamed Calendar" < $1.title ?? $1.firstValueForRawTagName("name") ?? "Unnamed Name" }, id: \.id) { calendarListEvent in
                            NavigationLink(destination: CalendarView(calendarListEvent: calendarListEvent).environmentObject(appState)) {
                                Text(calendarListEvent.title ?? calendarListEvent.firstValueForRawTagName("name") ?? "Unnamed Calendar")
                            }
                        }
                    },
                    header: {
                        Text(.localizable.currentCalendars)
                    }
                )
            }
        }
    }
}

struct CalendarsView_Previews: PreviewProvider {

    static let isoDateFormatter = ISO8601DateFormatter()

    static let nostrica = Conference(
        name: "Nostrica 2023",
        startDate: isoDateFormatter.date(from: "2023-03-19T09:00:00-06:00")!,
        endDate: isoDateFormatter.date(from: "2023-03-21T17:00:00-06:00")!,
        location: "Uvita, Costa Rica",
        timeZone: TimeZone(identifier: "America/Costa_Rica") ?? TimeZone.current,
        sessions: sessions,
        organizers: organizers
    )

    static let nostrasia = Conference(
        name: "Nostrasia 2023",
        startDate: isoDateFormatter.date(from: "2023-11-01T09:00:00+09:00")!,
        endDate: isoDateFormatter.date(from: "2023-11-03T17:00:00+09:00")!,
        location: "Tokyo, Japan",
        timeZone: TimeZone(identifier: "Asia/Tokyo") ?? TimeZone.current,
        sessions: sessions,
        organizers: organizers
    )

    static let conferences = [
        nostrica,
        nostrasia
    ]

    static let tyiu = Person(
        nostrPublicKey: "npub1yaul8k059377u9lsu67de7y637w4jtgeuwcmh5n7788l6xnlnrgs3tvjmf",
        name: "Terry Yiu",
        description: "Founder @ Comingle\nContributor @ Damus\nEngineer @ Cash App",
        picture:
"""
https://nostr.build/i/p/nostr.build_\
8156bdbedb3d551daaec740eda89e235816bfc20be5514d7781a848f7dcf960c.jpg
"""
    )

    static let jack = Person(
        nostrPublicKey: "npub1sg6plzptd64u62a878hep2kev88swjh3tw00gjsfl8f237lmu63q0uf63m",
        name: "Jack Dorsey",
        description: "Block Head",
        picture:
"""
https://nostr.build/i/p/nostr.build_\
6b9909bccf0f4fdaf7aacd9bc01e4ce70dab86f7d90395f2ce925e6ea06ed7cd.jpeg
"""
    )

    static let jb55 = Person(
        nostrPublicKey: "npub1xtscya34g58tk0z605fvr788k263gsu6cy9x0mhnm87echrgufzsevkk5s",
        name: "William Casarin",
        description: "",
        picture: "https://cdn.jb55.com/img/red-me.jpg"
    )

    static let derekross = Person(
        nostrPublicKey: "npub18ams6ewn5aj2n3wt2qawzglx9mr4nzksxhvrdc4gzrecw7n5tvjqctp424",
        name: "Derek Ross",
        description: "",
        picture: "https://void.cat/d/K2NTskLuQdNU7GsAq4DanP"
    )

    static let session1 = Session(
        id: "session1",
        name: "Globalization of Nostr",
        speakers: [
            tyiu,
            jack
        ],
        startTime: isoDateFormatter.date(from: "2023-03-19T09:00:00-06:00")!,
        endTime: isoDateFormatter.date(from: "2023-03-19T09:30:00-06:00")!,
        stage: "Open Source Stage",
        description:
"""
This talk will go over who uses Nostr around the world, \
and what needs to happen to truly be globally accessible.
"""
    )

    static let session2 = Session(
        id: "session2",
        name: "Intro to Damus",
        speakers: [
            jb55
        ],
        startTime: isoDateFormatter.date(from: "2023-03-19T09:30:00-06:00")!,
        endTime: isoDateFormatter.date(from: "2023-03-19T10:00:00-06:00")!,
        stage: "Open Source Stage",
        description: ""
    )

    static let session3 = Session(
        id: "session3",
        name: "NostrPlebs",
        speakers: [
            derekross
        ],
        startTime: isoDateFormatter.date(from: "2023-03-20T09:00:00-06:00")!,
        endTime: isoDateFormatter.date(from: "2023-03-20T09:30:00-06:00")!,
        stage: "Open Source Stage",
        description: ""
    )

    static let sessions = [
        session1,
        session2,
        session3
    ]

    static let organizers = [
        tyiu,
        jack,
        jb55
    ]

    @State static var appState = AppState()

    static var previews: some View {
        CalendarsView()
            .environmentObject(appState)
    }
}
