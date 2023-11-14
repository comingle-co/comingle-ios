//
//  DayView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI

struct DayView: View {
    private let sessionsByStartTime: [Date: [Session]]
    private let sortedStartTimes: [Date]
    private let dateIntervalFormatter = DateIntervalFormatter()
    private let timeFormatter = DateFormatter()
    private let calendar: Calendar

    init(sessions: [Session], calendar: Calendar) {
        self.calendar = calendar

        sessionsByStartTime = Dictionary(grouping: sessions) { $0.startTime }
        sortedStartTimes = sessionsByStartTime.keys.sorted()

        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        timeFormatter.timeZone = calendar.timeZone

        dateIntervalFormatter.dateStyle = .none
        dateIntervalFormatter.timeStyle = .short
        dateIntervalFormatter.timeZone = calendar.timeZone
    }

    var body: some View {
        List {
            ForEach(sortedStartTimes, id: \.self) { startTime in
                Section(
                    content: {
                        ForEach(sessionsByStartTime[startTime]!, id: \.self) { session in
                            NavigationLink(destination: SessionView(session: session, calendar: calendar)) {
                                VStack(alignment: .leading) {
                                    /*@START_MENU_TOKEN@*/Text(session.name)/*@END_MENU_TOKEN@*/
                                        .padding(.vertical, 2)
                                        .font(.headline)

                                    Divider()

                                    Text(session.speakers.map { $0.name }.joined(separator: ", ") )
                                        .padding(.vertical, 2)
                                        .font(.subheadline)

                                    Divider()

                                    Text(session.stage)
                                        .padding(.vertical, 2)
                                        .font(.subheadline)

                                    Text(dateIntervalFormatter.string(from: session.startTime, to: session.endTime))
                                        .font(.footnote)
                                }
                            }
                        }
                    },
                    header: {
                        Text(timeFormatter.string(from: startTime))
                    }
                )
            }
        }
    }
}

struct DayView_Previews: PreviewProvider {
    static var previews: some View {
        DayView(
            sessions: ConferencesView_Previews.sessions,
            calendar: Calendar.current
        )
    }
}
