//
//  SignInViewModel.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/12/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import Combine

final class SignInViewModel: ObservableObject {
    @Published var email: String
    @Published var password: String
    @Published private(set) var inputIsValid: Bool
    @Published private(set) var isLoading: Bool
    @Published private(set) var errorMessage: String

    private let userManager: UserManager
    private let networkModel: TeslaApi
    private var cancellables = Set<AnyCancellable>()

    init(userManager: UserManager, networkModel: TeslaApi) {
        self.userManager = userManager
        self.networkModel = networkModel
        self.email = ""
        self.password = ""
        self.inputIsValid = false
        self.isLoading = false
        self.errorMessage = ""

        $email.combineLatest($password, $isLoading)
            .map { !$0.0.isEmpty && !$0.1.isEmpty && !$0.2 }
            .assign(to: \.inputIsValid, on: self)
            .store(in: &cancellables)
    }

    func login() {
        errorMessage = ""
        isLoading = true
        networkModel.requestToken(for: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                guard case let .failure(error) = completion else { return }
                switch error {
                case TeslaApiError.httpUnauthorised:
                    self?.errorMessage = "Login failed. Invalid credentials."
                default:
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] token in
                self?.isLoading = false
                self?.userManager.apiToken = token
            })
            .store(in: &cancellables)
    }
}
