//
//  PersonView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/10/23.
//

import SwiftUI
import NostrSDK

struct PersonView: View {
    let person: CalendarEventParticipant

    var body: some View {
        VStack(alignment: .center) {
            Text(person.pubkey?.npub ?? "No pubkey")
                .font(.headline)
            Text(person.role ?? "No role")
                .font(.subheadline)
            Link(.localizable.nostrProfile, destination: URL(string: "nostr:\(person.pubkey!.hex)")!)
//            AsyncImage(url: URL(string: person.picture)) { image in
//                image.resizable()
//            } placeholder: {
//                ProgressView()
//            }
//            .frame(width: 200, height: 200)

        }
    }
}

struct PersonView_Previews: PreviewProvider {
    static var previews: some View {
//        PersonView(person: ConferencesView_Previews.tyiu)
        PersonView(person: CalendarEventParticipant(pubkey: Keypair()!.publicKey))
    }
}
