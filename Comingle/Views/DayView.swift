//
//  DayView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI
import NostrSDK

struct DayView: View {
    private let sessionsByStartTime: [Date: [TimeBasedCalendarEvent]]
    private let sortedStartTimes: [Date]
    private let dateIntervalFormatter = DateIntervalFormatter()
    private let timeFormatter = DateFormatter()
    private let calendar: Calendar

    init(sessions: [TimeBasedCalendarEvent], calendar: Calendar) {
        self.calendar = calendar

        sessionsByStartTime = Dictionary(grouping: sessions.filter { $0.startTimestamp != nil }) { $0.startTimestamp! }
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
                        ForEach(sessionsByStartTime[startTime].unsafelyUnwrapped, id: \.id) { event in
//                            guard let timeBasedCalendarEvent = event as TimeBasedCalendarEvent else {
//                                continue
//                            }
                            NavigationLink(destination: SessionView(session: event, calendar: calendar)) {
                                VStack(alignment: .leading) {
                                    Text(verbatim: event.title ?? event.firstValueForRawTagName("name") ?? "Unnamed Event")
                                        .padding(.vertical, 2)
                                        .font(.headline)

                                    Divider()

                                    Text(event.participants.map { $0.pubkey?.npub ?? "No npub" }.joined(separator: ", ") )
                                        .padding(.vertical, 2)
                                        .font(.subheadline)

                                    Divider()

                                    Text(event.locations.joined())
                                        .padding(.vertical, 2)
                                        .font(.subheadline)

                                    Text(dateIntervalFormatter.string(from: event.startTimestamp!, to: event.endTimestamp!))
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

//struct DayView_Previews: PreviewProvider {
//    static var previews: some View {
//        DayView(
//            sessions: ConferencesView_Previews.sessions,
//            calendar: Calendar.current
//        )
//    }
//}
