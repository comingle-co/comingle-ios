//
//  PersonView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI

struct PersonView: View {
    let person: Person

    var body: some View {
        VStack(alignment: .center) {
            Text(person.name)
                .font(.headline)
            Text(person.description)
                .font(.subheadline)
            Link(String(localized: LocalizedStringResource.localizable.nostrProfile), destination: URL(string: "nostr:\(person.nostrPublicKey)")!)
            AsyncImage(url: URL(string: person.picture)) { image in
                image.resizable()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 200, height: 200)

        }
    }
}

struct PersonView_Previews: PreviewProvider {
    static var previews: some View {
        PersonView(person: ConferencesView_Previews.tyiu)
    }
}
