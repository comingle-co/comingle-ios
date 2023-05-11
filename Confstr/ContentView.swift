//
//  ContentView.swift
//  Confstr
//
//  Created by Terry Yiu on 5/9/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ConferencesView(conferences: ConferencesView_Previews.conferences)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
