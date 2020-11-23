//
//  TeslaApi+liveStatus.swift
//  TeslaApi
//
//  Created by peter bohac on 4/12/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import Combine

extension TeslaApi {

    public func liveStatus(for siteId: Int) -> AnyPublisher<SiteStatus, Swift.Error> {
        let request = URLRequest(url: URL(string: "/api/1/energy_sites/\(siteId)/live_status", relativeTo: Constants.baseUri)!)

        return authoriseRequest(request)
            .flatMap { [urlSession] in urlSession.dataTaskPublisher(for: $0) }
            .tryMap(validateResponse)
            .decode(type: Response.self, decoder: Response.decoder)
            .map { $0.response }
            .eraseToAnyPublisher()
    }

    private struct Response: Decodable {
        let response: SiteStatus

        static let decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    }
}

public struct SiteStatus: Decodable {
    public enum GridStatus: String, Decodable {
        case active = "Active"
        case inactive = "Inactive"
    }

    public let solarPower: Double
    public let energyLeft: Double
    public let totalPackEnergy: Double
    public let percentageCharged: Double
    public let batteryPower: Double
    public let loadPower: Double
    public let gridPower: Double
    public let gridServicesPower: Double
    public let generatorPower: Double
    public let gridStatus: GridStatus
    public let gridServicesActive: Bool
    public let backupCapable: Bool
    public let stormModeActive: Bool
    public let timestamp: Date
}
