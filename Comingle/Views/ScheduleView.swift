//
//  ScheduleView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI

struct ScheduleView: View {
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
            let days = Array(Set(conference.sessions.map { calendar.startOfDay(for: $0.startTime) })).sorted()

            Picker(selection: $selectedDayIndex, label: Text("Date")) {
                ForEach(0..<days.count, id: \.self) { dayIndex in
                    Text("\(dateFormatter.string(from: days[dayIndex]))").tag(dayIndex)
                }
            }
            .pickerStyle(.segmented)

            ForEach(0..<days.count, id: \.self) { dayIndex in
                if selectedDayIndex == dayIndex {
                    DayView(
                        sessions: conference.sessions.filter {
                            calendar.startOfDay(for: $0.startTime) == days[dayIndex]
                        },
                        calendar: calendar
                    )
                }
            }
        }
    }
}

struct ScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleView(
            conference: ConferencesView_Previews.nostrica
        )
    }
}
