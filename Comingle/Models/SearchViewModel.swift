//
//  SearchViewModel.swift
//  Comingle
//
//  Created by Terry Yiu on 7/30/24.
//

import Foundation

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var debouncedSearchText = ""

    init() {
        // Debounce the search text
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .assign(to: &$debouncedSearchText)
    }
}
