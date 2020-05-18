//
//  UserManager.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/11/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import Valet

final class UserManager: ObservableObject {
    private let keychain = Valet.valet(with: Constants.keychainIdentity, accessibility: .whenUnlocked)
    private let defaults = UserDefaults.standard
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    var apiToken: TeslaToken? {
        get {
            guard let tokenData = keychain.object(forKey: Constants.tokenKey),
                let apiToken = try? jsonDecoder.decode(TeslaToken.self, from: tokenData) else { return nil }
            return apiToken
        }
        set {
            if let apiToken = newValue, let data = try? jsonEncoder.encode(apiToken) {
                keychain.set(object: data, forKey: Constants.tokenKey)
            } else {
                keychain.removeObject(forKey: Constants.tokenKey)
            }
            objectWillChange.send()
        }
    }

    var isAuthenticated: Bool {
        guard let apiToken = apiToken else { return false }
        return apiToken.validUntil > Date().addingTimeInterval(10) // 10 seconds
    }

    var energySite: (name: String, id: Int)? {
        get {
            guard let data = defaults.object(forKey: Constants.energySiteKey) as? Data,
                let site = try? jsonDecoder.decode(EnergySite.self, from: data) else { return nil }
            return (site.name, site.id)
        }
        set {
            if let value = newValue, let data = try? jsonEncoder.encode(EnergySite(name: value.name, id: value.id)) {
                defaults.setValue(data, forKey: Constants.energySiteKey)
            } else {
                defaults.removeObject(forKey: Constants.energySiteKey)
            }
        }
    }

    var showEnergyGraph: (battery: Bool, solar: Bool, house: Bool, grid: Bool)? {
        get {
            guard let data = defaults.object(forKey: Constants.energyGraphKey) as? Data,
                let energyGraph = try? jsonDecoder.decode(EnergyGraph.self, from: data) else { return nil }
            return (energyGraph.showBattery, energyGraph.showSolar, energyGraph.showHouse, energyGraph.showGrid)
        }
        set {
            if let value = newValue, let data = try? jsonEncoder.encode(EnergyGraph(showBattery: value.battery, showSolar: value.solar, showHouse: value.house, showGrid: value.grid)) {
                defaults.setValue(data, forKey: Constants.energyGraphKey)
            } else {
                defaults.removeObject(forKey: Constants.energyGraphKey)
            }
        }
    }

    func logout() {
        apiToken = nil
        energySite = nil
        showEnergyGraph = nil
    }

    private enum Constants {
        static let keychainIdentity = Identifier(nonEmpty: "net.1dot0.EnergyViewer")!
        static let tokenKey = "ApiToken"
        static let energySiteKey = "EnergySite"
        static let energyGraphKey = "EnergyGraph"
    }

    private struct EnergySite: Codable {
        let name: String
        let id: Int
    }

    private struct EnergyGraph: Codable {
        let showBattery: Bool
        let showSolar: Bool
        let showHouse: Bool
        let showGrid: Bool
    }
}
