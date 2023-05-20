//
//  PeopleView.swift
//  Confstr
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI

struct PeopleView: View {
    let speakers: [Person]
    let organizers: [Person]

    @State var selectedGroupIndex: Int = 0

    var body: some View {
        VStack {
            Picker(selection: $selectedGroupIndex, label: Text("Group")) {
                Text(
                    "Speakers",
                    comment: "Picker option to show list of conference speakers."
                ).tag(0)
                Text(
                    "Organizers",
                    comment: "Picker option to show list of conference organizers."
                ).tag(1)
            }
            .pickerStyle(.segmented)
            List {
                if selectedGroupIndex == 0 {
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
                            }.navigationTitle("People")
                        }
                    }
                } else {
                    ForEach(organizers, id: \.self) { speaker in
                        HStack {
                            AsyncImage(url: URL(string: speaker.picture)) { image in
                                image.resizable()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 100, height: 100)
                            NavigationLink(destination: PersonView(person: speaker)) {
                                Text(speaker.name)
                            }.navigationTitle("People")
                        }
                    }
                }
            }
        }
    }
}

struct PeopleView_Previews: PreviewProvider {
    static var previews: some View {
        PeopleView(
            speakers: [
                ConferencesView_Previews.tyiu,
                ConferencesView_Previews.jack,
                ConferencesView_Previews.jb55,
                ConferencesView_Previews.derekross
            ],
            organizers: [
            ]
        )
    }
}
