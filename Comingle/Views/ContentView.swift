//
//  ContentView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/9/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch appState.loginMode {
        case .none:
            LoginView()
        default:
            LoggedInView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {

    static var appState = AppState()

    static var previews: some View {
        ContentView()
            .environmentObject(appState)
    }
}
