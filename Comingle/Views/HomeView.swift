//
//  HomeView.swift
//  Comingle
//
//  Created by Terry Yiu on 6/22/24.
//

import Kingfisher
import NostrSDK
import SwiftData
import SwiftUI

struct HomeView: View {

    @State private var viewModel: ViewModel

    init(appState: AppState) {
        let viewModel = ViewModel(appState: appState)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        if viewModel.publicKeyHex != nil {
            EventListView(eventListType: .followed)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            EmptyView()
        }
    }
}

extension HomeView {
    @Observable class ViewModel {
        let appState: AppState

        init(appState: AppState) {
            self.appState = appState
        }

        var publicKeyHex: String? {
            appState.appSettings.activeProfile?.publicKeyHex
        }
    }
}

//struct HomeView_Previews: PreviewProvider {
//
//    @State static var appState = AppState()
//
//    static var previews: some View {
//        HomeView()
//            .environmentObject(appState)
//    }
//}
