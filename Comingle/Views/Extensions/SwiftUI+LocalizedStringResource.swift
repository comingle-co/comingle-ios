//
//  SwiftUI+LocalizedStringResource.swift
//  Comingle
//
//  Created by Terry Yiu on 1/6/24.
//

import Foundation
import SwiftUI

extension Button where Label == Text {
    init(_ title: LocalizedStringResource, action: @escaping () -> Void) {
        self.init(String(localized: title), action: action)
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ title: LocalizedStringResource, systemImage name: String) {
        self.init(String(localized: title), systemImage: name)
    }
}

extension Link where Label == Text {
    init(_ title: LocalizedStringResource, destination: URL) {
        self.init(String(localized: title), destination: destination)
    }
}

extension Picker where Label == Text {
    init(_ title: LocalizedStringResource, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.init(String(localized: title), selection: selection, content: content)
    }
}

extension TextField where Label == Text {
    init(localized: LocalizedStringResource, text: Binding<String>) {
        self.init(String(localized: localized), text: text)
    }
}

extension View {
    func navigationTitle(_ title: LocalizedStringResource) -> some View {
        navigationTitle(String(localized: title))
    }
}
