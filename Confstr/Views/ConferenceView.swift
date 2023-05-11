//
//  ConferenceView.swift
//  Confstr
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI

struct ConferenceView: View {
    private let conference: Conference
    private let dateFormatter = DateFormatter()
    private var calendar = Calendar.current

    @State var selectedDayIndex: Int = 0

    init(conference: Conference) {
        self.conference = conference

        calendar.timeZone = conference.timeZone

        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateFormatter.timeZone = conference.timeZone
    }

    var body: some View {
        VStack {
            TabView {
                ScheduleView(conference: conference)
                    .tabItem {
                        Label("Schedule", systemImage: "calendar")
                    }

                SpeakersView(speakers: Array(Set(conference.sessions.flatMap { $0.speakers })))
                    .tabItem {
                        Label("Speakers", systemImage: "person")
                    }
            }
        }
        .navigationTitle(conference.name)
    }
}

struct ConferenceView_Previews: PreviewProvider {
    static var previews: some View {
        ConferenceView(
            conference: ConferencesView_Previews.nostrica
        )
    }
}
