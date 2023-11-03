//
//  UserManager.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/11/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import OSLog
import TeslaAPI

final class UserManager: ObservableObject {
    private var keychain = Keychain()
    private var userDefaults = UserDefaults.standard

    var apiToken: Token? {
        get { keychain[Constants.tokenKey] }
        set {
            if newValue == nil {
                Logger.default.warning("[UserManager.apiToken] is being set to nil")
            } else {
                Logger.default.error("[UserManager.apiToken] new token is valid until: \(newValue!.validUntil.formatted(), privacy: .public)")
            }
            keychain[Constants.tokenKey] = newValue
            objectWillChange.send()
        }
    }

    var isAuthenticated: Bool { apiToken?.isValid ?? false }

    typealias EnergySite = (name: String, id: Int)
    var energySite: EnergySite? {
        get { userDefaults[Constants.energySiteKey]?.site }
        set { userDefaults[Constants.energySiteKey] = CodableEnergySite(newValue) }
    }

    typealias EnergyGraph = (battery: Bool, solar: Bool, house: Bool, grid: Bool)
    var showEnergyGraph: EnergyGraph? {
        get { userDefaults[Constants.energyGraphKey]?.graph }
        set { userDefaults[Constants.energyGraphKey] = CodableEnergyGraph(newValue) }
    }

    func logout() {
        apiToken = nil
        energySite = nil
        showEnergyGraph = nil
    }
}

private extension UserManager {
    enum Constants {
        static let tokenKey = Keychain.Key<Token>(name: "ApiToken")
        static let energySiteKey = UserDefaults.Key<CodableEnergySite>(name: "EnergySite")
        static let energyGraphKey = UserDefaults.Key<CodableEnergyGraph>(name: "EnergyGraph")
    }

    struct CodableEnergySite: Codable {
        let name: String
        let id: Int
        var site: EnergySite { (name, id) }
        init?(_ site: EnergySite?) {
            if let tuple = site {
                self.name = tuple.name
                self.id = tuple.id
            } else {
                return nil
            }
        }
    }

    struct CodableEnergyGraph: Codable {
        let showBattery: Bool
        let showSolar: Bool
        let showHouse: Bool
        let showGrid: Bool
        var graph: EnergyGraph { (showBattery, showSolar, showHouse, showGrid) }
        init?(_ graph: EnergyGraph?) {
            if let tuple = graph {
                self.showBattery = tuple.battery
                self.showSolar = tuple.solar
                self.showHouse = tuple.house
                self.showGrid = tuple.grid
            } else {
                return nil
            }
        }
    }
}

private extension UserDefaults {
    struct Key<Value> {
        var name: String
    }

    private enum Constants {
        static let decoder = JSONDecoder()
        static let encoder = JSONEncoder()
    }

    subscript<T: Codable>(key: Key<T>) -> T? {
        get {
            guard let data = object(forKey: key.name) as? Data,
                  let val = try? Constants.decoder.decode(T.self, from: data) else { return nil }
            return val
        }
        set {
            if let value = newValue, let data = try? Constants.encoder.encode(value) {
                setValue(data, forKey: key.name)
            } else {
                removeObject(forKey: key.name)
            }
        }
    }
}
