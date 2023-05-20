//
//  ConferencesView.swift
//  Confstr
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI

struct ConferencesView: View {

    private let calendar = Calendar.current

    private var currentConferences: [Conference] = []
    private var upcomingConferences: [Conference] = []
    private var pastConferences: [Conference] = []

    init(conferences: [Conference]) {
        let currentDate = Date.now

        conferences.forEach {
            let startDay = calendar.startOfDay(for: $0.startDate)
            let endDay = calendar.startOfDay(for: $0.endDate.addingTimeInterval(86400)) // 86400 seconds in 1 day

            if currentDate > endDay {
                pastConferences.append($0)
            } else if currentDate < startDay {
                upcomingConferences.append($0)
            } else {
                currentConferences.append($0)
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                if !currentConferences.isEmpty {
                    Section(
                        content: {
                            ForEach(currentConferences, id: \.self) { conference in
                                NavigationLink(destination: ConferenceView(conference: conference)) {
                                    Text(conference.name)
                                }
                            }
                        },
                        header: {
                            Text("Current Conferences", comment: "Section header for list of current conferences.")
                        }
                    )
                }

                if !upcomingConferences.isEmpty {
                    Section(
                        content: {
                            ForEach(upcomingConferences, id: \.self) { conference in
                                NavigationLink(destination: ConferenceView(conference: conference)) {
                                    Text(conference.name)
                                }
                            }
                        },
                        header: {
                            Text("Upcoming Conferences", comment: "Section header for list of upcoming conferences.")
                        }
                    )
                }

                if !pastConferences.isEmpty {
                    Section(
                        content: {
                            ForEach(pastConferences, id: \.self) { conference in
                                NavigationLink(destination: ConferenceView(conference: conference)) {
                                    Text(conference.name)
                                }
                            }
                        },
                        header: {
                            Text("Past Conferences", comment: "Section header for list of past conferences.")
                        }
                    )
                }
            }
            .navigationTitle("Conferences")
        }
    }
}

struct ConferencesView_Previews: PreviewProvider {

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
        description: "Founder @ Confstr\nContributor @ Damus\nEngineer @ Cash App",
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

    static var previews: some View {
        ConferencesView(conferences: conferences)
    }
}
