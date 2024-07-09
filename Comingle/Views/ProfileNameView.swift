//
//  ProfileNameView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/9/24.
//

import NostrSDK
import SwiftUI

struct ProfileNameView: View {
    var publicKeyHex: String?

    @EnvironmentObject var appState: AppState

    var body: some View {
        Text(Utilities.shared.profileName(publicKeyHex: publicKeyHex, appState: appState))
    }
}

#Preview {
    ProfileNameView()
}
