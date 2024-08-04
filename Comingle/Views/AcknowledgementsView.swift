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
                    if let url = URL(string: dependency.url) {
                        UIApplication.shared.open(url)
                    }
                }, label: {
                    LabeledContent(dependency.name, value: dependency.version)
                })
            }
        }
        .navigationTitle(.localizable.acknowledgements)
    }
}

struct Dependency: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    let url: String
}

@Observable class DependenciesManager {
    var dependencies: [Dependency] = []

    init() {
        loadDependencies()
    }

    func loadDependencies() {
        // Add your dependencies here
        dependencies = [
            Dependency(name: "CryptoSwift", version: "1.8.2", url: "https://github.com/krzyzanowskim/CryptoSwift"),
            Dependency(name: "GeohashKit", version: "3.0.0", url: "https://github.com/ualch9/GeohashKit"),
            Dependency(name: "Kingfisher", version: "7.12.0", url: "https://github.com/onevcat/Kingfisher"),
            Dependency(name: "Nostr SDK for Apple Platforms", version: "0a3e979", url: "https://github.com/nostr-sdk/nostr-sdk-ios"),
            Dependency(name: "Robohash", version: "Cats - David Revoy", url: "https://robohash.org/"),
            Dependency(name: "secp256k1", version: "0.12.2", url: "https://github.com/21-DOT-DEV/swift-secp256k1"),
            Dependency(name: "swift-collections", version: "1.1.2", url: "https://github.com/apple/swift-collections"),
            Dependency(name: "SwiftTrie", version: "0.1.2", url: "https://github.com/tyiu/swift-trie"),
            Dependency(name: "XCStringsToolPlugin", version: "0.1.1", url: "https://github.com/liamnichols/xcstrings-tool-plugin")
        ]
    }
}

#Preview {
    AcknowledgementsView()
}
