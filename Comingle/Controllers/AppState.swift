//
//  AppState.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import Foundation
import NostrSDK
import Combine

class AppState: ObservableObject {
    @Published var loginMode: LoginMode = .none
    @Published var relay: Relay?
    @Published var keypair: Keypair?
    @Published var calendarListEvents: [CalendarListEvent] = []
    @Published var timeBasedCalendarEvents: [TimeBasedCalendarEvent] = []

    init(loginMode: LoginMode = .none, relayUrlString: String? = nil, relay: Relay? = nil, keypair: Keypair? = nil) {
        self.loginMode = loginMode
        self.relay = relay
        self.keypair = keypair
    }
}

extension AppState: RelayDelegate {

    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        if state == .connected {
            let filter = Filter(
                kinds: [EventKind.calendar.rawValue, EventKind.timeBasedCalendarEvent.rawValue]
            )
            do {
                try relay.subscribe(with: filter)
            } catch {
                print("Could not subscribe to relay with calendar filter")
            }
        }
    }

    func relay(_ relay: Relay, didReceive event: RelayEvent) {
        DispatchQueue.main.async {
            let nostrEvent = event.event
            switch nostrEvent {
            case let calendarListEvent as CalendarListEvent:
                if !self.calendarListEvents.contains(where: { $0.id == calendarListEvent.id }) {
                    self.calendarListEvents.insert(calendarListEvent, at: 0)
                }
            case let timeBasedCalendarEvent as TimeBasedCalendarEvent:
                if !self.timeBasedCalendarEvents.contains(where: { $0.id == timeBasedCalendarEvent.id }) {
                    self.timeBasedCalendarEvents.insert(timeBasedCalendarEvent, at: 0)
                }
            default:
                break
            }
        }
    }

}
