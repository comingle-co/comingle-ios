//
//  CondensedProfilePicturesView.swift
//  Comingle
//
//  Created by Terry Yiu on 8/21/24.
//

import SwiftUI

struct CondensedProfilePicturesView: View {
    @EnvironmentObject var appState: AppState

    let pubkeys: [String]
    let maxPictures: Int

    init(pubkeys: [String], maxPictures: Int) {
        self.pubkeys = pubkeys
        self.maxPictures = min(maxPictures, pubkeys.count)
    }

    var body: some View {
        // Using ZStack to make profile pictures floating and stacked on top of each other.
        ZStack {
            ForEach((0..<maxPictures).reversed(), id: \.self) { index in
                ProfilePictureView(publicKeyHex: pubkeys[index], size: 20)
                    .offset(x: CGFloat(index) * 10)
            }
        }
        // Padding is needed so that other components drawn adjacent to this view don't get drawn on top.
        .padding(.trailing, CGFloat((maxPictures - 1) * 10))
    }
}

//#Preview {
//    CondensedProfilePicturesView()
//}
