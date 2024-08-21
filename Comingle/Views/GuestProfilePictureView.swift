//
//  GuestProfilePictureView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/8/24.
//

import SwiftUI

struct GuestProfilePictureView: View {
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: "person.crop.circle")
            .resizable()
            .scaledToFit()
            .frame(width: size)
            .clipShape(.circle)
    }
}

#Preview {
    GuestProfilePictureView()
}
