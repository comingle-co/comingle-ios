//
//  AppState.swift
//  Comingle
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

    init(loginMode: LoginMode = .none, relayUrlString: String? = nil, relay: Relay? = nil, keypair: Keypair? = nil) {
        self.loginMode = loginMode
        self.relayUrlString = relayUrlString
        self.relay = relay
        self.keypair = keypair
    }
}

extension AppState: RelayDelegate {

    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        if let keypair, state == .connected {
            _ = Filter(
                authors: [keypair.publicKey.hex],
                kinds: [EventKind.setMetadata.rawValue]
            )
        }
    }

    func relay(_ relay: Relay, didReceive event: RelayEvent) {
    }

}
