//
//  SessionView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI
import NostrSDK

struct SessionView: View {

    private let dateIntervalFormatter = DateIntervalFormatter()
    private let session: TimeBasedCalendarEvent
    private let calendar: Calendar

    init(session: TimeBasedCalendarEvent, calendar: Calendar) {
        self.session = session
        self.calendar = calendar

        dateIntervalFormatter.dateStyle = .none
        dateIntervalFormatter.timeStyle = .short
        dateIntervalFormatter.timeZone = calendar.timeZone
    }

    var body: some View {
        ScrollView {
            Text(session.title ?? session.firstValueForRawTagName("name") ?? "Unnamed Event")
                .padding(.vertical, 2)
                .font(.largeTitle)

            Divider()

            Text(session.locations.joined())
                .padding(.vertical, 2)
                .font(.subheadline)

            Text(dateIntervalFormatter.string(from: session.startTimestamp!, to: session.endTimestamp!))
                .font(.footnote)

            Divider()

            Text(session.content)
                .padding(.vertical, 2)
                .font(.subheadline)

            Divider()

            Text(.localizable.participants)
                .padding(.vertical, 2)
                .font(.title)
            ForEach(session.participants, id: \.self) { participant in
                Text(participant.pubkey?.npub ?? "No npub")
//                PersonView(person: participant)
//                Link(.localizable.zapWithCommentOrQuestion, destination: URL(string: "lightning:tyiu@tyiu.xyz")!)
                Divider()
            }
        }
    }
}

//struct SessionView_Previews: PreviewProvider {
//    static var previews: some View {
//        SessionView(session: TimeBasedCalendarEvent(content: "description", signedBy: Keypair()!), calendar: Calendar.current)
//    }
//}
