//
//  SessionView.swift
//  Confstr
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI

struct SessionView: View {

    private let dateIntervalFormatter = DateIntervalFormatter()
    private let session: Session
    private let calendar: Calendar

    init(session: Session, calendar: Calendar) {
        self.session = session
        self.calendar = calendar

        dateIntervalFormatter.dateStyle = .none
        dateIntervalFormatter.timeStyle = .short
        dateIntervalFormatter.timeZone = calendar.timeZone
    }

    var body: some View {
        ScrollView {
            Text(session.name)
                .padding(.vertical, 2)
                .font(.largeTitle)

            Divider()

            Text(session.stage)
                .padding(.vertical, 2)
                .font(.subheadline)

            Text(dateIntervalFormatter.string(from: session.startTime, to: session.endTime))
                .font(.footnote)

            Divider()

            Text(session.description)
                .padding(.vertical, 2)
                .font(.subheadline)

            Divider()

            Text("Speakers:")
                .padding(.vertical, 2)
                .font(.title)
            ForEach(session.speakers, id: \.self) { speaker in
                PersonView(person: speaker)
                Link("⚡️ Zap with comment or question", destination: URL(string: "lightning:tyiu@tyiu.xyz")!)
                Divider()
            }
        }
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionView(session: ConferencesView_Previews.session1, calendar: Calendar.current)
    }
}
