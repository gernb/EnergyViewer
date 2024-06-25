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

    public func liveStatus(for siteId: Int) -> AnyPublisher<LiveStatus, Swift.Error> {
        let request = URLRequest(url: URL(string: "/api/1/energy_sites/\(siteId)/live_status", relativeTo: Constants.baseUri)!)

        return authenticateAndPerform(request: request)
//            .map { data -> Data in
//                print(String(data: data, encoding: .utf8)!)
//                return data
//            }
            .decode(type: Response.self, decoder: Response.decoder)
            .map(\.response)
            .eraseToAnyPublisher()
    }

    private struct Response: Decodable {
        let response: LiveStatus

        static let decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    }
}

public struct LiveStatus: Decodable {
    public enum GridStatus: String, Decodable {
        case active = "Active"
        case inactive = "Inactive"
    }

    public let solarPower: Double
    public let percentageCharged: Double
    public let batteryPower: Double
    public let loadPower: Double
    public let gridPower: Double
//    public let gridServicesPower: Double
    public let generatorPower: Double
    public let gridStatus: GridStatus
//    public let gridServicesActive: Bool
//    public let backupCapable: Bool
    public let stormModeActive: Bool
    public let timestamp: Date
}
