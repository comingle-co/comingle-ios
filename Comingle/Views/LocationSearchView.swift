//
//  LocationSearchView.swift
//  Comingle
//
//  Created by Terry Yiu on 8/1/24.
//

import GeohashKit
import MapKit
import SwiftUI

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var autocompleteManager = MKAutocompleteManager()

    @Binding var location: String
    @Binding var geohash: String

    @State private var mapItem: MKMapItem?
    @State private var newMapItem: MKMapItem?

    var body: some View {
        VStack {
            TextField(localized: .localizable.searchForLocation, text: $autocompleteManager.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
                .onChange(of: autocompleteManager.searchText) { oldValue, newValue in
                    if oldValue.trimmingCharacters(in: .whitespacesAndNewlines) != newValue.trimmingCharacters(in: .whitespacesAndNewlines) {
                        mapItem = nil
                        autocompleteManager.updateSearchResults()
                    }
                    if let newMapItem {
                        mapItem = newMapItem
                        self.newMapItem = nil
                    }
                }

            if let searchGeohash {
                Map(bounds: MapCameraBounds(centerCoordinateBounds: searchGeohash.region)) {
                    Marker(autocompleteManager.searchText, coordinate: searchGeohash.region.center)
                }
                .frame(height: 250)
            }

            List(autocompleteManager.completions, id: \.self) { completion in
                Button(action: {
                    performSearch(for: completion)
                }, label: {
                    VStack(alignment: .leading) {
                        Text(completion.title)
                            .font(.headline)
                        Text(completion.subtitle)
                            .font(.subheadline)
                    }
                })
            }
        }
        .toolbar {
            Button(action: {
                location = autocompleteManager.searchText
                geohash = searchGeohash?.geohash ?? ""
                dismiss()
            }, label: {
                Text(.localizable.addLocation)
            })
        }
        .task {
            autocompleteManager.searchText = location
        }
    }

    private func performSearch(for completion: MKLocalSearchCompletion) {
        let query = completion.displayName
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = completion.displayName

        let localSearch = MKLocalSearch(request: searchRequest)
        localSearch.start { (response, error) in
            guard let response = response, let mapItem = response.mapItems.first else {
                print("Search error: \(error?.localizedDescription ?? "Unknown error")")
                self.newMapItem = nil
                autocompleteManager.searchText = query
                return
            }

            self.newMapItem = mapItem
            autocompleteManager.searchText = mapItem.displayName
        }
    }

    private var trimmedGeohash: String {
        geohash.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchGeohash: Geohash? {
        if let mapItem {
            let coordinate = mapItem.placemark.coordinate

            // Precision of 10 gives an area ≤ 1.19m x 0.596m
            return Geohash(coordinates: (coordinate.latitude, coordinate.longitude), precision: 10)
        } else {
            let trimmedGeohash = trimmedGeohash
            if location == autocompleteManager.searchText, !trimmedGeohash.isEmpty {
                return Geohash(geohash: trimmedGeohash)
            } else {
                return nil
            }
        }
    }
}

extension MKLocalSearchCompletion {
    var displayName: String {
        "\(title), \(subtitle)"
    }
}

extension MKMapItem {
    var displayName: String {
        var result: [String] = []
        if let title = placemark.title {
            if let name, !title.starts(with: name) {
                result.append(name)
            }
            result.append(title)
        }
        if let subtitle = placemark.subtitle {
            result.append(subtitle)
        }
        return result.joined(separator: ", ")
    }
}

//#Preview {
//    LocationSearchView()
//}
