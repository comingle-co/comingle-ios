//
//  AcknowledgementsView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/29/24.
//

import SwiftUI

struct AcknowledgementsView: View {
    private var dependenciesManager = DependenciesManager()

    var body: some View {
        List(dependenciesManager.dependencies) { dependency in
            VStack(alignment: .leading) {
                Button(action: {
                    if let urlString = dependency.url, let url = URL(string: urlString) {
                        UIApplication.shared.open(url)
                    }
                }, label: {
                    LabeledContent(dependency.name, value: dependency.version)
                })
            }
        }
        .navigationTitle(String(localized: "Acknowledgements", comment: "View for seeing the acknowledgements of projects that this app depends on."))
    }
}

struct Dependency: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    let url: String?
}

@Observable class DependenciesManager {
    var dependencies: [Dependency] = []

    init() {
        loadDependencies()
    }

    func loadDependencies() {
        // Add your dependencies here
        dependencies = [
            Dependency(name: "Comingle Logo", version: "The: Daniel⚡️", url: Utilities.shared.externalNostrProfileURL(npub: "npub1aeh2zw4elewy5682lxc6xnlqzjnxksq303gwu2npfaxd49vmde6qcq4nwx")?.absoluteString),
            Dependency(name: "CryptoSwift", version: "1.8.2", url: "https://github.com/krzyzanowskim/CryptoSwift"),
            Dependency(name: "GeohashKit", version: "3.0.0", url: "https://github.com/ualch9/GeohashKit"),
            Dependency(name: "Kingfisher", version: "7.12.0", url: "https://github.com/onevcat/Kingfisher"),
            Dependency(name: "Nostr SDK for Apple Platforms", version: "9ec53aa", url: "https://github.com/nostr-sdk/nostr-sdk-ios"),
            Dependency(name: "Robohash", version: "Cats - David Revoy", url: "https://robohash.org/"),
            Dependency(name: "secp256k1", version: "0.12.2", url: "https://github.com/21-DOT-DEV/swift-secp256k1"),
            Dependency(name: "swift-collections", version: "1.1.2", url: "https://github.com/apple/swift-collections"),
            Dependency(name: "SwiftTrie", version: "0.1.2", url: "https://github.com/tyiu/swift-trie")
        ]
    }
}

#Preview {
    AcknowledgementsView()
}
