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

    public func powerHistory(for siteId: Int, endDate: Date? = nil) -> AnyPublisher<[TimePeriodPower], Swift.Error> {
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
            .decode(type: PowerResponse.self, decoder: PowerResponse.decoder)
            .map(\.response.timeSeries)
            .eraseToAnyPublisher()
    }

    fileprivate struct PowerResponse: Decodable {
        struct Response: Decodable {
            let serialNumber: String
            let installationTimeZone: String
            let timeSeries: [TimePeriodPower]
        }

        let response: Response

        static let decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    }

    // MARK: - Energy History

    public func energyHistory(for siteId: Int, period: TimePeriod, endDate: Date? = nil) -> AnyPublisher<[TimePeriodEnergy], Swift.Error> {
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
            .decode(type: EnergyResponse.self, decoder: EnergyResponse.decoder)
            .map(\.response.timeSeries)
            .eraseToAnyPublisher()
    }

    fileprivate struct EnergyResponse: Decodable {
        struct Response: Decodable {
            let serialNumber: String
            let period: TimePeriod
            let installationTimeZone: String
            let timeSeries: [TimePeriodEnergy]
        }

        let response: Response

        static let decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    }

    // MARK: - Self Consumption History

    public func selfConsumptionHistory(for siteId: Int, period: TimePeriod, endDate: Date? = nil) -> AnyPublisher<[SelfConsumptionEnergy], Swift.Error> {
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
            .decode(type: SelfConsumptionResponse.self, decoder: SelfConsumptionResponse.decoder)
            .map(\.response.timeSeries)
            .eraseToAnyPublisher()
    }

    fileprivate struct SelfConsumptionResponse: Decodable {
        struct Response: Decodable {
            let period: TimePeriod
            let timezone: String
            let timeSeries: [SelfConsumptionEnergy]
        }

        let response: Response

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

public struct TimePeriodPower: Decodable {
    public let timestamp: Date
    public let solarPower: Double
    public let batteryPower: Double
    public let gridPower: Double
    public let gridServicesPower: Double
    public let generatorPower: Double
}

public struct TimePeriodEnergy: Decodable {
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
}

public struct SelfConsumptionEnergy: Decodable {
    public let timestamp: Date
    public let solar: Double
    public let battery: Double
}

fileprivate extension Date {
    var asISO8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.string(from: self)
    }
}
