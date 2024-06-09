//
//  TeslaApi+calendarHistory.swift
//  TeslaApi
//
//  Created by peter bohac on 4/13/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import Combine

extension TeslaApi {

    // MARK: - Power History

    public func powerHistory(for siteId: Int, endDate: Date? = nil) -> AnyPublisher<PowerHistory, Swift.Error> {
        let url: URL = {
            let url = URL(string: "/api/1/energy_sites/\(siteId)/calendar_history", relativeTo: Constants.baseUri)!
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            components.queryItems = [
                URLQueryItem(name: "kind", value: "power")
            ]
            if let endDate = endDate {
                components.queryItems!.append(URLQueryItem(name: "end_date", value: endDate.asISO8601))
            }
            return components.url!
        }()
        let request = URLRequest(url: url)

        return authenticateAndPerform(request: request)
//            .map { data -> Data in
//                print(String(data: data, encoding: .utf8)!)
//                return data
//            }
            .decode(type: PowerResponse.self, decoder: PowerResponse.decoder)
            .map(\.response)
            .eraseToAnyPublisher()
    }

    fileprivate struct PowerResponse: Decodable {
        let response: PowerHistory

        static let decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    }

    // MARK: - Energy History

    public func energyHistory(for siteId: Int, period: TimePeriod, endDate: Date? = nil) -> AnyPublisher<EneryHistory, Swift.Error> {
        let url: URL = {
            let url = URL(string: "/api/1/energy_sites/\(siteId)/calendar_history", relativeTo: Constants.baseUri)!
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            components.queryItems = [
                URLQueryItem(name: "kind", value: "energy"),
                URLQueryItem(name: "period", value: period.rawValue)
            ]
            if let endDate = endDate {
                components.queryItems!.append(URLQueryItem(name: "end_date", value: endDate.asISO8601))
            }
            return components.url!
        }()
        let request = URLRequest(url: url)

        return authenticateAndPerform(request: request)
//            .map { data -> Data in
//                print(String(data: data, encoding: .utf8)!)
//                return data
//            }
            .decode(type: EnergyResponse.self, decoder: EnergyResponse.decoder)
            .map(\.response)
            .eraseToAnyPublisher()
    }

    fileprivate struct EnergyResponse: Decodable {
        let response: EneryHistory

        static let decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    }

    // MARK: - Self Consumption History

    public func selfConsumptionHistory(for siteId: Int, period: TimePeriod, endDate: Date? = nil) -> AnyPublisher<SelfConsumptionHistory, Swift.Error> {
        let url: URL = {
            let url = URL(string: "/api/1/energy_sites/\(siteId)/calendar_history", relativeTo: Constants.baseUri)!
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            components.queryItems = [
                URLQueryItem(name: "kind", value: "self_consumption"),
                URLQueryItem(name: "period", value: period.rawValue)
            ]
            if let endDate = endDate {
                components.queryItems!.append(URLQueryItem(name: "end_date", value: endDate.asISO8601))
            }
            return components.url!
        }()
        let request = URLRequest(url: url)

        return authenticateAndPerform(request: request)
//            .map { data -> Data in
//                print(String(data: data, encoding: .utf8)!)
//                return data
//            }
            .decode(type: SelfConsumptionResponse.self, decoder: SelfConsumptionResponse.decoder)
            .map(\.response)
            .eraseToAnyPublisher()
    }

    fileprivate struct SelfConsumptionResponse: Decodable {
        let response: SelfConsumptionHistory

        static let decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    }

}

public enum TimePeriod: String, Codable {
    case day, week, month, year, lifetime
}

public struct PowerHistory: Decodable {
    public let serialNumber: String
    public let installationTimeZone: String
    public let timeSeries: [PowerEntry]

    public var timeZone: TimeZone? { TimeZone(identifier: installationTimeZone) }

    public struct PowerEntry: Decodable {
        public let timestamp: Date
        public let solarPower: Double
        public let batteryPower: Double
        public let gridPower: Double
        public let gridServicesPower: Double
        public let generatorPower: Double
    }
}

public struct EneryHistory: Decodable {
    public let serialNumber: String
    public let period: TimePeriod
    public let installationTimeZone: String
    public let timeSeries: [EnergyEntry]

    public var timeZone: TimeZone? { TimeZone(identifier: installationTimeZone) }

    public struct EnergyEntry: Decodable {
        public let timestamp: Date
        public let solarEnergyExported: Double
        public let generatorEnergyExported: Double
        public let gridEnergyImported: Double
        public let gridServicesEnergyImported: Double
        public let gridServicesEnergyExported: Double
        public let gridEnergyExportedFromSolar: Double
        public let gridEnergyExportedFromGenerator: Double
        public let gridEnergyExportedFromBattery: Double
        public let batteryEnergyExported: Double
        public let batteryEnergyImportedFromGrid: Double
        public let batteryEnergyImportedFromSolar: Double
        public let batteryEnergyImportedFromGenerator: Double
        public let consumerEnergyImportedFromGrid: Double
        public let consumerEnergyImportedFromSolar: Double
        public let consumerEnergyImportedFromBattery: Double
        public let consumerEnergyImportedFromGenerator: Double
        public let rawTimestamp: Date
        public let totalHomeUsage: Double?
        public let totalBatteryDischarge: Double?
        public let totalGridEnergyExported: Double?
    }
}

public struct SelfConsumptionHistory: Decodable {
    public let period: TimePeriod
    public let timezone: String
    public let timeSeries: [SelfConsumptionEntry]

    public var timeZone: TimeZone? { TimeZone(identifier: timezone) }

    public struct SelfConsumptionEntry: Decodable {
        public let timestamp: Date
        public let solar: Double
        public let battery: Double
    }
}

public extension EneryHistory.EnergyEntry {
    static let zero = Self(
        timestamp: .now,
        solarEnergyExported: 0,
        generatorEnergyExported: 0,
        gridEnergyImported: 0,
        gridServicesEnergyImported: 0,
        gridServicesEnergyExported: 0,
        gridEnergyExportedFromSolar: 0,
        gridEnergyExportedFromGenerator: 0,
        gridEnergyExportedFromBattery: 0,
        batteryEnergyExported: 0,
        batteryEnergyImportedFromGrid: 0,
        batteryEnergyImportedFromSolar: 0,
        batteryEnergyImportedFromGenerator: 0,
        consumerEnergyImportedFromGrid: 0,
        consumerEnergyImportedFromSolar: 0,
        consumerEnergyImportedFromBattery: 0,
        consumerEnergyImportedFromGenerator: 0,
        rawTimestamp: .now,
        totalHomeUsage: 0,
        totalBatteryDischarge: 0,
        totalGridEnergyExported: 0
    )

    static func + (lhs: Self, rhs: Self) -> Self {
        .init(
            timestamp: rhs.timestamp,
            solarEnergyExported: lhs.solarEnergyExported + rhs.solarEnergyExported,
            generatorEnergyExported: lhs.generatorEnergyExported + rhs.generatorEnergyExported,
            gridEnergyImported: lhs.gridEnergyImported + rhs.gridEnergyImported,
            gridServicesEnergyImported: lhs.gridServicesEnergyImported + rhs.gridServicesEnergyImported,
            gridServicesEnergyExported: lhs.gridServicesEnergyExported + rhs.gridServicesEnergyExported,
            gridEnergyExportedFromSolar: lhs.gridEnergyExportedFromSolar + rhs.gridEnergyExportedFromSolar,
            gridEnergyExportedFromGenerator: lhs.gridEnergyExportedFromGenerator + rhs.gridEnergyExportedFromGenerator,
            gridEnergyExportedFromBattery: lhs.gridEnergyExportedFromBattery + rhs.gridEnergyExportedFromBattery,
            batteryEnergyExported: lhs.batteryEnergyExported + rhs.batteryEnergyExported,
            batteryEnergyImportedFromGrid: lhs.batteryEnergyImportedFromGrid + rhs.batteryEnergyImportedFromGrid,
            batteryEnergyImportedFromSolar: lhs.batteryEnergyImportedFromSolar + rhs.batteryEnergyImportedFromSolar,
            batteryEnergyImportedFromGenerator: lhs.batteryEnergyImportedFromGenerator + rhs.batteryEnergyImportedFromGenerator,
            consumerEnergyImportedFromGrid: lhs.consumerEnergyImportedFromGrid + rhs.consumerEnergyImportedFromGrid,
            consumerEnergyImportedFromSolar: lhs.consumerEnergyImportedFromSolar + rhs.consumerEnergyImportedFromSolar,
            consumerEnergyImportedFromBattery: lhs.consumerEnergyImportedFromBattery + rhs.consumerEnergyImportedFromBattery,
            consumerEnergyImportedFromGenerator: lhs.consumerEnergyImportedFromGenerator + rhs.consumerEnergyImportedFromGenerator,
            rawTimestamp: rhs.rawTimestamp,
            totalHomeUsage: (lhs.totalHomeUsage ?? 0) + (rhs.totalHomeUsage ?? 0),
            totalBatteryDischarge: (lhs.totalBatteryDischarge ?? 0) + (rhs.totalBatteryDischarge ?? 0),
            totalGridEnergyExported: (lhs.totalGridEnergyExported ?? 0) + (rhs.totalGridEnergyExported ?? 0)
        )
    }
}

fileprivate extension Date {
    var asISO8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.string(from: self)
    }
}
