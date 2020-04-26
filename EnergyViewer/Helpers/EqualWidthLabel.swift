//
//  EqualWidthLabel.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/13/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import SwiftUI

struct EqualWidthLabel: View {
    let text: String
    @Binding var width: CGFloat

    var body: some View {
        Text(text)
            .background(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .preference(key: WidthPreferenceKey.self, value: geometry.size.width / 2)
                }.scaledToFill()
            )
            .frame(maxWidth: self.width, alignment: .trailing)
            .onPreferenceChange(WidthPreferenceKey.self) { self.width = max($0, self.width) }
    }
}

fileprivate struct WidthPreferenceKey: PreferenceKey {
    typealias Value = CGFloat

    static var defaultValue = CGFloat.zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct EqualWidthLabel_Previews: PreviewProvider {
    @State static var maxWidth: CGFloat = 150

    static var previews: some View {
        EqualWidthLabel(text: "Some text", width: $maxWidth)
            .previewLayout(.sizeThatFits).padding()
    }
}
