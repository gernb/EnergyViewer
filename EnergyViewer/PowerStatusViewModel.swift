//
//  PowerStatusViewModel.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/13/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Combine
import Foundation
import TeslaAPI

enum FlowState {
    case notInUse, consuming, exporting, generating, house
}

struct Source: Identifiable {
    let id: String
    let subtitle: String
    let textPower: String
    let powerInKW: Double
    let state: FlowState
}

protocol PowerStatusViewModel: ObservableObject {
    var alert: AlertItem? { get set }
    var sources: [Source] { get }
    var batteryChargePercent: Double { get }
    var batteryChargeText: String { get }
    var batteryChargeSubtitle: String { get }
    var gridIsOffline: Bool { get }
    var stormModeActive: Bool { get }
    var rawStatus: String { get }
}

final class NetworkPowerStatusViewModel: PowerStatusViewModel {
    @Published private(set) var sources: [Source] = [
        Source(id: "Battery", subtitle: "", textPower: "", powerInKW: 0, state: .notInUse),
        Source(id: "Solar", subtitle: "", textPower: "", powerInKW: 0, state: .notInUse),
        Source(id: "House", subtitle: "", textPower: "", powerInKW: 0, state: .notInUse),
        Source(id: "Grid", subtitle: "", textPower: "", powerInKW: 0, state: .notInUse),
    ]
    @Published private(set) var batteryChargePercent: Double = 0
    @Published private(set) var batteryChargeText: String = ""
    @Published private(set) var batteryChargeSubtitle: String = ""
    @Published private(set) var gridIsOffline: Bool = false
    @Published private(set) var stormModeActive: Bool = false
    @Published private(set) var rawStatus: String = "Loading..."
    @Published var alert: AlertItem?

    private let siteId: Int
    private let userManager: UserManager
    private let networkModel: TeslaApiProviding
    private var timerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init(siteId: Int, userManager: UserManager, networkModel: TeslaApiProviding) {
        self.siteId = siteId
        self.userManager = userManager
        self.networkModel = networkModel

        beginMonitoring()
    }

    private func beginMonitoring() {
        monitorForLogout()

        guard userManager.isAuthenticated else { return }

        fetchStatus()
        pollForNewData()
    }

    private func monitorForLogout() {
        userManager.objectWillChange
            .sink { [weak self] in
                guard let strongSelf = self else { return }
                if !strongSelf.userManager.isAuthenticated {
                    strongSelf.timerCancellable = nil
                }
            }
            .store(in: &cancellables)
    }

    private func fetchStatus() {
        networkModel.liveStatus(for: siteId)
            .receive(on: DispatchQueue.main)
            .catch(handleError)
            .sink { [weak self] status in
                self?.updateStatus(status)
            }
            .store(in: &cancellables)
    }

    private func pollForNewData() {
        timerCancellable = Timer.publish(every: Constants.refreshInterval, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchStatus()
            }
    }

    private func updateStatus(_ status: SiteStatus) {
        // Battery
        batteryChargePercent = status.percentageCharged
        batteryChargeText = String(format: "%.0f%%", status.percentageCharged)
        batteryChargeSubtitle = String(format: "(%.1f / %.1f kWh)", status.energyLeft / 1000, status.totalPackEnergy / 1000)
        let batterySource: Source = {
            let power = status.batteryPower / 1000
            let textPower = String(format: "%.1f kW", abs(status.batteryPower / 1000))
            let subtitle: String
            let state: FlowState
            if status.batteryPower < 0 {
                subtitle = "(charging)"
                state = .exporting
            } else if status.batteryPower > 0 {
                subtitle = "(discharging)"
                state = .consuming
            } else {
                subtitle = ""
                state = .notInUse
            }
            return Source(id: "Battery", subtitle: subtitle, textPower: textPower, powerInKW: power, state: state)
        }()

        // Solar
        let solarSource: Source = {
            let power = status.solarPower / 1000
            let textPower = String(format: "%.1f kW", abs(status.solarPower / 1000))
            let subtitle: String
            let state: FlowState
            if status.solarPower > 0 {
                subtitle = "(generating)"
                state = .generating
            } else {
                subtitle = ""
                state = .notInUse
            }
            return Source(id: "Solar", subtitle: subtitle, textPower: textPower, powerInKW: power, state: state)
        }()

        // House
        let houseSource: Source = {
            let power = status.loadPower / 1000
            let textPower = String(format: "%.1f kW", abs(status.loadPower / 1000))
            let subtitle = ""
            let state: FlowState
            if status.loadPower > 0 {
                state = .house
            } else {
                state = .notInUse
            }
            return Source(id: "House", subtitle: subtitle, textPower: textPower, powerInKW: power, state: state)
        }()

        // Grid
        let gridSource: Source = {
            let power = status.gridPower / 1000
            let textPower = String(format: "%.1f kW", abs(status.gridPower / 1000))
            let subtitle: String
            let state: FlowState
            if status.gridPower < 0 {
                subtitle = "(exporting)"
                state = .exporting
            } else if status.gridPower > 0 {
                subtitle = "(consuming)"
                state = .consuming
            } else {
                subtitle = ""
                state = .notInUse
            }
            return Source(id: "Grid", subtitle: subtitle, textPower: textPower, powerInKW: power, state: state)
        }()

        sources = [batterySource, solarSource, houseSource, gridSource]
        gridIsOffline = status.gridStatus == .inactive
        stormModeActive = status.stormModeActive
        rawStatus = "\(status)"
//        print("Updated at \(status.timestamp)")
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

    private enum Constants {
        static let refreshInterval: TimeInterval = 3
    }
}
