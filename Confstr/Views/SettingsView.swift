//
//  SettingsView.swift
//  Confstr
//
//  Created by Terry Yiu on 6/18/23.
//

import SwiftUI

struct SettingsView: View {

    @Binding var loginMode: LoginMode

    var body: some View {
        NavigationStack {
            Form {
                Button("Logout") {
                    loginMode = .none
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct SettingsView_Previews: PreviewProvider {

    @State static var loginMode: LoginMode = .guest(relayAddress: LoginView.defaultRelay)

    static var previews: some View {
        SettingsView(loginMode: $loginMode)
    }
}
