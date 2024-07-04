//
//  ScheduleView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI
import NostrSDK

struct ScheduleView: View {
//    private let conference: Conference
    private let sessions: [TimeBasedCalendarEvent]
    @EnvironmentObject private var appState: AppState
    private let dateFormatter = DateFormatter()
    private var calendar = Calendar.current

    @State var selectedDayIndex: Int = 0

    init(sessions: [TimeBasedCalendarEvent]) {
//        self.conference = conference

//        calendar.timeZone = conference.timeZone

        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
//        dateFormatter.timeZone = conference.timeZone

        self.sessions = sessions
    }

    var body: some View {
        if sessions.isEmpty {
            Text(.localizable.noEvents)
        } else {
            VStack {
                let days = sessions
                    .filter { $0.startTimestamp != nil && $0.endTimestamp != nil }
                    .map { calendar.startOfDay(for: $0.startTimestamp!) }
                    .sorted()
                //            let days = Array(Set(conference.sessions.map { calendar.startOfDay(for: $0.startTime) })).sorted()

                Picker(selection: $selectedDayIndex, label: Text(.localizable.scheduleDatePickerLabel)) {
                    ForEach(0..<days.count, id: \.self) { dayIndex in
                        Text(dateFormatter.string(from: days[dayIndex])).tag(dayIndex)
                    }
                }
                .pickerStyle(.wheel)

                ForEach(0..<days.count, id: \.self) { dayIndex in
                    if selectedDayIndex == dayIndex {
                        DayView(
                            sessions: sessions.filter {
                                guard let startTimestamp = $0.startTimestamp else {
                                    return false
                                }
                                return calendar.startOfDay(for: startTimestamp) == days[dayIndex]
                            },
                            calendar: calendar
                        )
                        .environmentObject(appState)
                    }
                }
            }
        }
    }
}

//struct ScheduleView_Previews: PreviewProvider {
//    static var previews: some View {
//        ScheduleView(
//            conference: ConferencesView_Previews.nostrica
//        )
//    }
//}
