//
//  ContentView.swift
//  Confstr
//
//  Created by Terry Yiu on 5/9/23.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        switch appState.loginMode {
        case .none:
            LoginView(appState: appState)
        default:
            LoggedInView(appState: appState)
        }
    }
}

struct ContentView_Previews: PreviewProvider {

    static var appState = AppState()

    static var previews: some View {
        ContentView(appState: appState)
    }
}
