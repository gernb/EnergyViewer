//
//  HomeViewModel.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/11/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import UIKit
import Combine

enum HomeViewModelState<PowerStatusVM: PowerStatusViewModel, PowerHistoryVM: PowerHistoryViewModel> {
    case loggedOut
    case loading
    case loggedIn(siteName: String, PowerStatusVM, PowerHistoryVM)
}

protocol HomeViewModel: ObservableObject {
    associatedtype PowerStatusViewModelType: PowerStatusViewModel
    associatedtype PowerHistoryViewModelType: PowerHistoryViewModel

    var userManager: UserManager { get }
    var networkModel: TeslaApi { get }
    var state: HomeViewModelState<PowerStatusViewModelType, PowerHistoryViewModelType> { get }
    var showSignIn: Bool { get set }
    var alert: AlertItem? { get set }

    func logout()
}

final class NetworkHomeViewModel: HomeViewModel {
    typealias State = HomeViewModelState<NetworkPowerStatusViewModel, NetworkPowerHistoryViewModel>
    let userManager = UserManager()
    let networkModel: TeslaApi
    @Published private(set) var state: State
    @Published var showSignIn: Bool
    @Published var alert: AlertItem?

    private var cancellables = Set<AnyCancellable>()

    init() {
        UIApplication.shared.isIdleTimerDisabled = true
        networkModel = TeslaApiNetworkModel(token: userManager.apiToken)

        if (userManager.isAuthenticated) {
            showSignIn = false
            state = .loading
            loadData()
        } else {
            showSignIn = true
            state = .loggedOut
        }

        monitorForLogoutLogin()
        periodicallyRefreshToken()
    }

    func logout() {
        userManager.logout()
    }

    private func monitorForLogoutLogin() {
        userManager.objectWillChange
            .sink { [weak self] in
                guard let strongSelf = self else { return }
                if strongSelf.userManager.isAuthenticated {
                    strongSelf.showSignIn = false
                    strongSelf.state = .loading
                    strongSelf.loadData()
                } else {
                    strongSelf.showSignIn = true
                    strongSelf.state = .loggedOut
                }
            }
            .store(in: &cancellables)
    }

    private func periodicallyRefreshToken() {
        Publishers.MergeMany(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification),
            NotificationCenter.default.publisher(for: .NSCalendarDayChanged))
            .sink { [weak self] _ in
                self?.refreshToken()
            }
            .store(in: &cancellables)
    }

    private func refreshToken() {
        guard userManager.isAuthenticated else { return }
        networkModel.refreshToken()
            .receive(on: DispatchQueue.main)
            .catch(handleError)
            .map { token -> TeslaToken? in token } // this is stupid
            .assign(to: \.apiToken, on: userManager)
            .store(in: &self.cancellables)
    }

    private func loadData() {
        guard userManager.isAuthenticated else { return }
        getSiteInfo()
            .receive(on: DispatchQueue.main)
            .catch(handleError)
            .compactMap { [weak self] site -> State? in
                guard let strongSelf = self else { return nil }
                let powerStatusVM = NetworkPowerStatusViewModel(siteId: site.id, userManager: strongSelf.userManager, networkModel: strongSelf.networkModel)
                let powerHistoryVM = NetworkPowerHistoryViewModel(siteId: site.id, userManager: strongSelf.userManager, networkModel: strongSelf.networkModel)
                return .loggedIn(siteName: site.name, powerStatusVM, powerHistoryVM)
            }
            .assign(to: \.state, on: self)
            .store(in: &self.cancellables)
    }

    private func getSiteInfo() -> AnyPublisher<(name: String, id: Int), Swift.Error> {
        if let site = userManager.energySite {
            return Just(site)
                .setFailureType(to: Swift.Error.self)
                .eraseToAnyPublisher()
        } else {
            return networkModel.listProducts()
                .tryMap { [weak self] products in
                    guard let energySite = products.first(where: { $0 is TeslaEnergySite }) as? TeslaEnergySite else { throw Error.noEnergySitesFound }
                    let site = (energySite.siteName, energySite.energySiteId)
                    self?.userManager.energySite = site
                    return site
                }
                .eraseToAnyPublisher()
        }
    }

    private func handleError<T>(_ error: Swift.Error) -> Empty<T, Never> {
        switch error {
        case TeslaApiError.httpUnauthorised:
            alert = AlertItem(title: "Error", text: "You have been logged out.", buttonText: "Ok") { [userManager] in
                userManager.logout()
            }
        default:
            alert = AlertItem(title: "Error", text: "\(error)", buttonText: "Ok", action: nil)
        }
        return Empty(completeImmediately: true)
    }

    private enum Error: Swift.Error {
        case noEnergySitesFound
    }
}
