//
//  SignInView.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/12/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import SwiftUI
import Combine

struct SignInView: View {
    @ObservedObject private var viewModel: SignInViewModel
    @State private var maxLabelWidth = CGFloat.zero

    init(userManager: UserManager, api: TeslaApi) {
        viewModel = SignInViewModel(userManager: userManager, api: api)
    }

    var body: some View {
        VStack {
            HStack {
                EqualWidthLabel(text: "Email:", width: $maxLabelWidth)
                TextField("", text: $viewModel.email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            HStack {
                EqualWidthLabel(text: "Password:", width: $maxLabelWidth)
                SecureField("", text: $viewModel.password) { self.viewModel.login() }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
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

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView(userManager: UserManager(), api: TeslaApi())
    }
}
