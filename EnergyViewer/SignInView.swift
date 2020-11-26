//
//  SignInView.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/12/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Combine
import SwiftUI
import TeslaAPI

struct SignInView: View {
    @ObservedObject private var viewModel: SignInViewModel
    private var textFieldWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 250 : 400
    }

    init(userManager: UserManager, networkModel: TeslaApiProviding) {
        viewModel = SignInViewModel(userManager: userManager, networkModel: networkModel)
    }

    var body: some View {
        VStack {
            VStack(alignment: .equalWidths) {
                HStack {
                    Text("Email:")
                        .alignmentGuide(.equalWidths) { d in d[.trailing] }
                    TextField("", text: $viewModel.email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: textFieldWidth)
                }
                HStack {
                    Text("Password:")
                        .alignmentGuide(.equalWidths) { d in d[.trailing] }
                    SecureField("", text: $viewModel.password) { self.viewModel.login() }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: textFieldWidth)
                }
            }
            Button(action: { self.viewModel.login() }) {
                if viewModel.isLoading {
                    Wrap(UIActivityIndicatorView()) {
                        $0.startAnimating()
                        $0.color = .systemBlue
                    }
                } else {
                    Text("Login")
                }
            }
                .padding()
                .background(viewModel.inputIsValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!viewModel.inputIsValid)
            if !viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .frame(maxWidth: 500)
        .keyboardDodging()
    }
}

fileprivate extension HorizontalAlignment {
    struct EqualWidths: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.leading]
        }
    }

    static let equalWidths = HorizontalAlignment(EqualWidths.self)
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView(userManager: UserManager(), networkModel: TeslaApi())
    }
}
