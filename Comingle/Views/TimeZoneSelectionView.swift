//
//  TimeZoneSelectionView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/29/24.
//

import Foundation
import SwiftTrie
import SwiftUI

struct TimeZoneSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    @State var date: Date
    @Binding private var timeZone: TimeZone?
    @State private var search: String = ""

    private let trie = Trie<TimeZone>()

    private let knownTimeZones: [TimeZone]

    init(date: Date, timeZone: Binding<TimeZone?>) {
        self.date = date
        self._timeZone = timeZone

        self.knownTimeZones = TimeZone.knownTimeZoneIdentifiers
            .compactMap { TimeZone(identifier: $0) }
            .sorted(using: TimeZoneSortComparator(order: .forward, date: date))

        self.knownTimeZones
            .forEach { timeZone in
                _ = trie.insert(
                    key: timeZone.displayName(for: date),
                    value: timeZone,
                    options: [.includeCaseInsensitiveMatches, .includeNonPrefixedMatches]
                )
            }
    }

    var searchResults: [TimeZone] {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            knownTimeZones
        } else {
            trie.find(key: search.localizedLowercase)
                .sorted(using: TimeZoneSortComparator(order: .forward, date: date))
        }
    }

    var body: some View {
        NavigationStack {
            List(searchResults, id: \.self, selection: $timeZone) { timeZone in
                Text(timeZone.displayName(for: date))
                    .bold(self.timeZone?.identifier == timeZone.identifier)
            }
            .searchable(
                text: $search,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: String(localized: .localizable.searchForTimeZone)
            )
            .onChange(of: timeZone) {
                dismiss()
            }
        }
    }
}

#Preview {
    @Previewable @State var timeZone: TimeZone? = TimeZone.autoupdatingCurrent
    return TimeZoneSelectionView(date: Date.now, timeZone: $timeZone)
}
