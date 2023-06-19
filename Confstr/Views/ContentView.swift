//
//  ContentView.swift
//  Confstr
//
//  Created by Terry Yiu on 5/9/23.
//

import SwiftUI

struct ContentView: View {
    @State private var loginMode: LoginMode = .none

    var body: some View {
        switch loginMode {
        case .none:
            LoginView(loginMode: $loginMode)
        default:
            LoggedInView(loginMode: $loginMode)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
