//
//  TeslaApi+liveStatus.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/12/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import Combine

extension TeslaApiNetworkModel {

    public func liveStatus(for siteId: Int) -> AnyPublisher<TeslaSiteStatus, Swift.Error> {
        let request = URLRequest(url: URL(string: "/api/1/energy_sites/\(siteId)/live_status", relativeTo: Constants.baseUri)!)

        return authoriseRequest(request)
            .flatMap { [urlSession] in urlSession.dataTaskPublisher(for: $0) }
            .tryMap(validateResponse)
            .decode(type: Response.self, decoder: Response.decoder)
            .map { $0.response }
            .eraseToAnyPublisher()
    }

    private struct Response: Decodable {
        let response: TeslaSiteStatus

        static let decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    }
}

public struct TeslaSiteStatus: Decodable {
    let solarPower: Double
    let energyLeft: Double
    let totalPackEnergy: Double
    let percentageCharged: Double
    let batteryPower: Double
    let loadPower: Double
    let gridPower: Double
    let gridServicesPower: Double
    let generatorPower: Double
    let gridStatus: String
    let gridServicesActive: Bool
    let backupCapable: Bool
    let stormModeActive: Bool
    let timestamp: Date
}
