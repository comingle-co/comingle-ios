//
//  ImageOverlayView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/25/24.
//

import SwiftUI

struct ImageOverlayView<BackgroundView: View>: View {
    let imageSystemName: String
    let overlayBackgroundColor: Color
    @ViewBuilder let backgroundView: () -> BackgroundView

    var body: some View {
        ZStack {
            backgroundView()

            Circle()
                .fill(overlayBackgroundColor)
                .frame(width: 16, height: 16)
                .offset(x: 12, y: 12)
                .overlay(
                    Image(systemName: imageSystemName)
                        .resizable()
                        .scaledToFill()
                        .foregroundColor(.white)
                        .frame(maxWidth: 6, maxHeight: 6)
                        .offset(x: 12, y: 12)
                )
        }
    }
}

#Preview {
    ImageOverlayView(imageSystemName: "lock.fill", overlayBackgroundColor: .accent) {
        Image(systemName: "person.crop.circle")
            .resizable()
            .scaledToFit()
            .frame(width: 40)
            .clipShape(.circle)
    }
}
