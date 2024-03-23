//
//  TeslaApi+siteStatus.swift
//  TeslaApi
//
//  Created by peter bohac on 3/23/24.
//  Copyright © 2024 1dot0 Solutions. All rights reserved.
//

import Foundation
import Combine

extension TeslaApi {

    public func siteStatus(for siteId: Int) -> AnyPublisher<SiteStatus, Swift.Error> {
        let request = URLRequest(url: URL(string: "/api/1/energy_sites/\(siteId)/site_status", relativeTo: Constants.baseUri)!)

        return authenticateAndPerform(request: request)
            .map { data -> Data in
                print(String(data: data, encoding: .utf8)!)
                return data
            }
            .decode(type: Response.self, decoder: Response.decoder)
            .map(\.response)
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
    public let resourceType: String
    public let siteName: String
    public let gatewayId: String
//    public let energyLeft: Double
//    public let totalPackEnergy: Double
    public let percentageCharged: Double
    public let batteryType: String
    public let backupCapable: Bool
    public let batteryPower: Double
    public let stormModeEnabled: Bool
    public let powerwallOnboardingSettingsSet: Bool
    public let powerwallTeslaElectricInterestedIn: Bool?
    public let syncGridAlertEnabled: Bool
    public let breakerAlertEnabled: Bool
}
