//
//  KeyboardDodging.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/12/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Combine
import SwiftUI

extension View {
//    func keyboardDodging(_ keyboardHeight: Binding<CGFloat>) -> some View {
//        ModifiedContent(content: self, modifier: KeyboardDodging(keyboardHeight: keyboardHeight))
//    }

    func keyboardDodging() -> some View {
        ModifiedContent(content: self, modifier: KeyboardDodging())
    }
}

fileprivate struct KeyboardDodging: ViewModifier {
    @State private var overlap = CGFloat.zero
    @State private var contentFrame = CGRect.zero
    @State private var keyboardFrame = CGRect.zero

    func body(content: Content) -> some View {
        content
            .padding(.bottom, overlap)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: GeometryPreferenceKey.self, value: geometry.frame(in: .global))
                }
            )
            .onPreferenceChange(GeometryPreferenceKey.self) { contentFrame in
                self.contentFrame = contentFrame.offsetBy(dx: 0, dy: -self.overlap)
                self.overlap = 2 *  self.contentFrame.intersection(self.keyboardFrame).height
            }
            .onReceive(Publishers.keyboardFrame) { keyboardFrame in
                self.keyboardFrame = keyboardFrame
                self.overlap = 2 *  self.contentFrame.intersection(self.keyboardFrame).height
            }
            .animation(.easeOut(duration: 0.16), value: overlap)
    }
}

/*
fileprivate struct KeyboardDodging: ViewModifier {
    @Binding var keyboardHeight: CGFloat

    @State private var contentFrame = CGRect.zero
    @State private var keyboardFrame = CGRect.zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: GeometryPreferenceKey.self, value: geometry.frame(in: .global))
                }
            )
            .onPreferenceChange(GeometryPreferenceKey.self) { contentFrame in
                self.contentFrame = contentFrame
                self.keyboardHeight = self.contentFrame.intersection(self.keyboardFrame).height
            }
            .onReceive(Publishers.keyboardFrame) { keyboardFrame in
                self.keyboardFrame = keyboardFrame
                self.keyboardHeight = self.contentFrame.intersection(self.keyboardFrame).height
            }
            .animation(.easeOut(duration: 0.16))
    }
}
*/

fileprivate struct GeometryPreferenceKey: PreferenceKey {
    typealias Value = CGRect
    static var defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {}
}

fileprivate extension Publishers {
    static var keyboardFrame: AnyPublisher<CGRect, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }

        let willHide = NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }

        let willChange = NotificationCenter.default.publisher(for: UIApplication.keyboardWillChangeFrameNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }

        return MergeMany(willShow, willHide, willChange)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
