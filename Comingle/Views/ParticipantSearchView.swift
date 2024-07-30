//
//  ParticipantSearchView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/30/24.
//

import NostrSDK
import OrderedCollections
import SwiftUI

struct ParticipantSearchView: View {
    @Environment(\.dismiss) private var dismiss

    @State var appState: AppState
    @Binding private var participants: Set<EventCreationParticipant>

    @State private var participantSearch: String = ""

    @State private var roleText: String = ""

    let eventCreationParticipantSortComparator: EventCreationParticipantSortComparator

    init(appState: AppState, participants: Binding<Set<EventCreationParticipant>>) {
        self.appState = appState
        self._participants = participants

        eventCreationParticipantSortComparator = EventCreationParticipantSortComparator(order: .forward, appState: appState)
    }

    var trimmedParticipantSearch: String {
        participantSearch.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var participantSearchResults: OrderedSet<EventCreationParticipant> {
        let trimmedParticipantSearch = trimmedParticipantSearch

        if trimmedParticipantSearch.isEmpty {
            let sortedParticipants = OrderedSet(participants.sorted(using: eventCreationParticipantSortComparator))

            if let publicKey = appState.publicKey, let followListEvent = appState.followListEvents[publicKey.hex] {
                return sortedParticipants.union(
                    followListEvent.followedPubkeys
                        .filter { appState.metadataEvents[$0] != nil }
                        .map { EventCreationParticipant(publicKeyHex: $0) }
                        .sorted(using: eventCreationParticipantSortComparator)
                    )
            } else {
                return sortedParticipants
            }
        } else {
            let searchResults = appState.metadataTrie.find(key: trimmedParticipantSearch.localizedLowercase)
                .map { EventCreationParticipant(publicKeyHex: $0.pubkey) }
                .sorted(using: eventCreationParticipantSortComparator)

            if !searchResults.isEmpty {
                return OrderedSet(searchResults)
            }

            if let publicKey = PublicKey(npub: trimmedParticipantSearch) {
                return OrderedSet(arrayLiteral: EventCreationParticipant(publicKeyHex: publicKey.hex))
            }

            return []
        }
    }

    var body: some View {
        List {
            ForEach(participantSearchResults, id: \.self) { participant in
                Button {
                    if participants.contains(participant) {
                        participants.remove(participant)
                    } else {
                        participants.insert(participant)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            ProfilePictureAndNameView(publicKeyHex: participant.publicKeyHex)
                                .environmentObject(appState)

                            if participants.contains(participant) {
                                let roleBinding = Binding<String>(
                                    get: {
                                        participant.role
                                    },
                                    set: {
                                        participant.role = $0
                                    }
                                )
                                TextField(localized: .localizable.role, text: roleBinding)
                            }
                        }

                        Spacer()

                        if participants.contains(participant) {
                            Image(systemName: "checkmark")
                        }
                    }
                    .foregroundStyle(participants.contains(participant) ? .accent : .primary)
                }
            }
        }
        .searchable(text: $participantSearch, placement: .navigationBarDrawer(displayMode: .always), prompt: String(localized: .localizable.searchForParticipant))
    }
}

//#Preview {
//    ProfileSearchView()
//}
