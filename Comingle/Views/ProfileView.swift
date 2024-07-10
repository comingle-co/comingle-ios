//
//  ProfileView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/7/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct ProfileView: View {

    @EnvironmentObject var appState: AppState

    @State var publicKeyHex: String?

    var body: some View {
        VStack {
            if let publicKeyHex {
                ProfilePictureAndNameView(publicKeyHex: publicKeyHex)
                CalendarEventListView(calendarEventListType: .profile(publicKeyHex))
            } else {
                LoginView()
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {

    @State static var appState = AppState()

    static var previews: some View {
        ProfileView()
            .environmentObject(appState)
    }
}
