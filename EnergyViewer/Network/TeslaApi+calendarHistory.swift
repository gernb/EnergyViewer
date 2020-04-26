//
//  TeslaApi+calendarHistory.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/13/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import Combine

extension TeslaApi {

    enum Period: String, Codable {
        case day, week, month, year, lifetime
    }

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

        return authoriseRequest(request)
            .flatMap { [urlSession] in urlSession.dataTaskPublisher(for: $0) }
            .tryMap(validateResponse)
            .decode(type: PowerResponse.self, decoder: PowerResponse.decoder)
            .map { $0.response.timeSeries }
            .eraseToAnyPublisher()
    }

    struct TimePeriodPower: Decodable {
        let timestamp: Date
        let solarPower: Double
        let batteryPower: Double
        let gridPower: Double
        let gridServicesPower: Double
        let generatorPower: Double
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

    public func energyHistory(for siteId: Int, period: Period, endDate: Date? = nil) -> AnyPublisher<[TimePeriodEnergy], Swift.Error> {
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

        return authoriseRequest(request)
            .flatMap { [urlSession] in urlSession.dataTaskPublisher(for: $0) }
            .tryMap(validateResponse)
            .decode(type: EnergyResponse.self, decoder: EnergyResponse.decoder)
            .map { $0.response.timeSeries }
            .eraseToAnyPublisher()
    }

    struct TimePeriodEnergy: Decodable {
        let timestamp: Date
        let solarEnergyExported: Double
        let generatorEnergyExported: Double
        let gridEnergyImported: Double
        let gridServicesEnergyImported: Double
        let gridServicesEnergyExported: Double
        let gridEnergyExportedFromSolar: Double
        let gridEnergyExportedFromGenerator: Double
        let gridEnergyExportedFromBattery: Double
        let batteryEnergyExported: Double
        let batteryEnergyImportedFromGrid: Double
        let batteryEnergyImportedFromSolar: Double
        let batteryEnergyImportedFromGenerator: Double
        let consumerEnergyImportedFromGrid: Double
        let consumerEnergyImportedFromSolar: Double
        let consumerEnergyImportedFromBattery: Double
        let consumerEnergyImportedFromGenerator: Double
    }

    fileprivate struct EnergyResponse: Decodable {
        struct Response: Decodable {
            let serialNumber: String
            let period: Period
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

    public func selfConsumptionHistory(for siteId: Int, period: Period, endDate: Date? = nil) -> AnyPublisher<[SelfConsumptionEnergy], Swift.Error> {
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

        return authoriseRequest(request)
            .flatMap { [urlSession] in urlSession.dataTaskPublisher(for: $0) }
            .tryMap(validateResponse)
            .decode(type: SelfConsumptionResponse.self, decoder: SelfConsumptionResponse.decoder)
            .map { $0.response.timeSeries }
            .eraseToAnyPublisher()
    }

    struct SelfConsumptionEnergy: Decodable {
        let timestamp: Date
        let solar: Double
        let battery: Double
    }

    fileprivate struct SelfConsumptionResponse: Decodable {
        struct Response: Decodable {
            let period: Period
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

fileprivate extension Date {
    var asISO8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.string(from: self)
    }
}
