//
//  TeslaApi+listProducts.swift
//  TeslaApi
//
//  Created by peter bohac on 4/12/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import Combine

extension TeslaApi {

    public func listProducts() -> AnyPublisher<[Product], Swift.Error> {
        let request = URLRequest(url: URL(string: "/api/1/products", relativeTo: Constants.baseUri)!)

        return authenticateAndPerform(request: request)
//            .map { data -> Data in
//                print(String(data: data, encoding: .utf8)!)
//                return data
//            }
            .decode(type: Response.self, decoder: Response.decoder)
            .map(\.response)
            .eraseToAnyPublisher()
    }

    fileprivate struct Response: Decodable {
        let response: [Product]
        let count: Int

        private enum CodingKeys: CodingKey {
            case response, count
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.count = try container.decode(Int.self, forKey: .count)
            self.response = try container.decode([AnyProduct].self, forKey: .response).map { $0.product }
        }

        static let decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return decoder
        }()
    }

    fileprivate struct AnyProduct: Product, Decodable {
        let product: Product

        private enum CodingKeys: CodingKey {
            case vehicleId, energySiteId
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.vehicleId) {
                self.product = try Vehicle(from: decoder)
            } else if container.contains(.energySiteId) {
                self.product = try EnergySite(from: decoder)
            } else {
                throw TeslaApiError.decoding("Unsupported product type")
            }
        }
    }

}

public protocol Product {}

public struct Vehicle: Product, Decodable {
    public let id: Int
    public let vehicleId: Int
    public let displayName: String
    public let optionCodes: String
}

public struct EnergySite: Product, Decodable {
    public let energySiteId: Int
    public let resourceType: String
    public let siteName: String
    public let id: String
    public let gatewayId: String
    public let assetSiteId: String
    public let warpSiteNumber: String
//    public let energyLeft: Double
//    public let totalPackEnergy: Double
    public let percentageCharged: Double
    public let batteryType: String
//    public let backupCapable: Bool
    public let batteryPower: Double
    public let stormModeEnabled: Bool
    public let syncGridAlertEnabled: Bool
    public let breakerAlertEnabled: Bool
    /*
     "go_off_grid_test_banner_enabled": null,
     "powerwall_onboarding_settings_set": true,
     "powerwall_tesla_electric_interested_in": null,
     "vpp_tour_enabled": null,
     "components": {
       "battery": true,
       "battery_type": "ac_powerwall",
       "solar": true,
       "grid": true,
       "load_meter": true,
       "market_type": "residential"
     },
     "features": {
       "rate_plan_manager_no_pricing_constraint": true
     }
     */
}

public extension TeslaApiProviding {
    func listEnergySites() -> AnyPublisher<[EnergySite], Swift.Error> {
        return listProducts()
            .map { products in
                products.compactMap { $0 as? EnergySite }
            }
            .eraseToAnyPublisher()
    }

    func listVehicles() -> AnyPublisher<[Vehicle], Swift.Error> {
        return listProducts()
            .map { products in
                products.compactMap { $0 as? Vehicle }
            }
            .eraseToAnyPublisher()
    }
}
