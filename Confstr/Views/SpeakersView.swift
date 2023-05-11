//
//  SpeakersView.swift
//  Confstr
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI

struct SpeakersView: View {
    let speakers: [Person]

    var body: some View {
        List {
            ForEach(speakers, id: \.self) { speaker in
                HStack {
                    AsyncImage(url: URL(string: speaker.picture)) { image in
                        image.resizable()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 100, height: 100)
                    NavigationLink(destination: PersonView(person: speaker)) {
                        Text(speaker.name)
                    }.navigationTitle("Speakers")
                }
            }
        }
    }
}

struct SpeakersView_Previews: PreviewProvider {
    static var previews: some View {
        SpeakersView(speakers: [
            ConferencesView_Previews.tyiu,
            ConferencesView_Previews.jack,
            ConferencesView_Previews.jb55,
            ConferencesView_Previews.derekross
        ])
    }
}
