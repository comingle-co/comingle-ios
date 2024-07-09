//
//  GuestProfilePictureView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/8/24.
//

import SwiftUI

struct GuestProfilePictureView: View {
    var body: some View {
        Image(systemName: "person.crop.circle")
            .resizable()
            .scaledToFit()
            .frame(width: 40)
            .clipShape(.circle)
    }
}

#Preview {
    GuestProfilePictureView()
}
