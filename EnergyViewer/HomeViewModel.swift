//
//  HomeViewModel.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/11/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Combine
import OSLog
import TeslaAPI
import UIKit

enum HomeViewModelState<PowerStatusVM: PowerStatusViewModel, PowerHistoryVM: PowerHistoryViewModel> {
    case loggedOut
    case loading
    case loggedIn(siteName: String, PowerStatusVM, PowerHistoryVM)
}

protocol HomeViewModel: ObservableObject {
    associatedtype PowerStatusViewModelType: PowerStatusViewModel
    associatedtype PowerHistoryViewModelType: PowerHistoryViewModel

    var userManager: UserManager { get }
    var networkModel: TeslaApiProviding { get }
    var state: HomeViewModelState<PowerStatusViewModelType, PowerHistoryViewModelType> { get }
    var alert: AlertItem? { get set }

    func login()
    func logout()
    func refreshToken()
}

final class NetworkHomeViewModel: HomeViewModel {
    typealias State = HomeViewModelState<NetworkPowerStatusViewModel, NetworkPowerHistoryViewModel>
    let userManager = UserManager()
    let networkModel: TeslaApiProviding
    @Published private(set) var state: State
    @Published var alert: AlertItem?

    private var cancellables = Set<AnyCancellable>()

    init() {
        UIApplication.shared.isIdleTimerDisabled = true
        networkModel = TeslaApi(token: userManager.apiToken, onDidUpdateToken: { [userManager] token in
            Logger.default.info("[NetworkHomeViewModel.onDidUpdateToken] token valid until: \(token?.validUntil.formatted() ?? "nil", privacy: .public)")
            userManager.apiToken = token
        })

        if userManager.isAuthenticated {
            state = .loading
            loadData()
        } else {
            state = .loggedOut
        }

        monitorForLogoutLogin()
        periodicallyRefreshToken()
    }

    func login() {
        networkModel.requestToken()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: handleCompletion,
                receiveValue: { _ in }
            )
            .store(in: &self.cancellables)
    }

    func logout() {
        userManager.logout()
    }

    func refreshToken() {
        networkModel.refreshToken()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: handleCompletion,
                receiveValue: { _ in }
            )
            .store(in: &self.cancellables)
    }

    private func monitorForLogoutLogin() {
        userManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let strongSelf = self else { return }
                if strongSelf.userManager.isAuthenticated {
                    strongSelf.state = .loading
                    strongSelf.loadData()
                } else {
                    strongSelf.state = .loggedOut
                }
            }
            .store(in: &cancellables)
    }

    private func periodicallyRefreshToken() {
        Publishers.MergeMany(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification),
            NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
        )
        .sink { [weak self] _ in
            Logger.default.info("[NetworkHomeViewModel.periodicallyRefreshToken] refreshing the auth token")
            self?.refreshToken()
        }
        .store(in: &cancellables)
    }

    private func loadData() {
        getSiteInfo()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: handleCompletion,
                receiveValue: { [weak self] site in
                    guard let self else { return }
                    let powerStatusVM = NetworkPowerStatusViewModel(siteId: site.id, userManager: self.userManager, networkModel: self.networkModel)
                    let powerHistoryVM = NetworkPowerHistoryViewModel(siteId: site.id, userManager: self.userManager, networkModel: self.networkModel)
                    self.state = .loggedIn(siteName: site.name, powerStatusVM, powerHistoryVM)
                }
            )
            .store(in: &self.cancellables)
    }

    private func getSiteInfo() -> AnyPublisher<(name: String, id: Int), Swift.Error> {
        if let site = userManager.energySite {
            return Just(site)
                .setFailureType(to: Swift.Error.self)
                .eraseToAnyPublisher()
        } else {
            return networkModel.listEnergySites()
                .tryMap { [weak self] energySites in
                    guard let energySite = energySites.first else { throw Error.noEnergySitesFound }
                    let site = (energySite.siteName, energySite.energySiteId)
                    self?.userManager.energySite = site
                    return site
                }
                .eraseToAnyPublisher()
        }
    }

    private func handleCompletion<E: Swift.Error>(_ completion: Subscribers.Completion<E>) {
        guard case .failure(let error) = completion else { return }
        Logger.default.error("[NetworkHomeViewModel.handleCompletion] \(String(describing: error), privacy: .public)")
        if let teslaApiError = error as? TeslaApiError, teslaApiError == .httpUnauthorised {
            alert = AlertItem(title: "Error", text: "You have been logged out.", buttonText: "Ok") { [userManager] in
                userManager.logout()
            }
        } else {
            alert = AlertItem(title: "Error", text: "\(error)", buttonText: "Ok", action: nil)
        }
    }

    private enum Error: Swift.Error {
        case noEnergySitesFound
    }
}
