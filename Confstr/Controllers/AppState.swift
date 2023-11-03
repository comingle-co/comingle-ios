//
//  AppState.swift
//  Confstr
//
//  Created by Terry Yiu on 6/18/23.
//

import Foundation
import NostrSDK

class AppState: ObservableObject {
    @Published var loginMode: LoginMode = .none
    @Published var relayUrlString: String?
    @Published var relay: Relay?
    @Published var keypair: Keypair?
}

extension AppState: RelayDelegate {

    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        if let keypair, state == .connected {
            let filter = Filter(
                authors: [keypair.privateKey.hex],
                kinds: [EventKind.setMetadata.rawValue]
            )
        }
    }

    func relay(_ relay: Relay, didReceive event: NostrEvent) {
    }

}
