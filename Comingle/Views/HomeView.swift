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

    init(modelContext: ModelContext, appState: AppState) {
        let viewModel = ViewModel(modelContext: modelContext, appState: appState)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        if viewModel.publicKeyHex == nil {
            LoginView(modelContext: viewModel.modelContext, appState: viewModel.appState)
        } else {
            EventListView(eventListType: .followed)
                .navigationTitle(.localizable.yourNetwork)
        }
    }
}

extension HomeView {
    class ViewModel: ObservableObject {
        let modelContext: ModelContext
        let appState: AppState

        init(modelContext: ModelContext, appState: AppState) {
            self.modelContext = modelContext
            self.appState = appState
        }

        var publicKeyHex: String? {
            appState.appSettings?.activeProfile?.publicKeyHex
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
