//
//  TeslaApi+listProducts.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/12/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import Combine

extension TeslaApi {

    public func listProducts() -> AnyPublisher<[TeslaProduct], Swift.Error> {
        let request = URLRequest(url: URL(string: "/api/1/products", relativeTo: Constants.baseUri)!)

        return authoriseRequest(request)
            .flatMap { [urlSession] in urlSession.dataTaskPublisher(for: $0) }
            .tryMap(validateResponse)
            .decode(type: Response.self, decoder: Response.decoder)
            .map { $0.response }
            .eraseToAnyPublisher()
    }

    struct Vehicle: TeslaProduct, Decodable {
        let id: Int
        let vehicleId: Int
        let displayName: String
        let optionCodes: String
    }

    struct EnergySite: TeslaProduct, Decodable {
        let energySiteId: Int
        let resourceType: String
        let siteName: String
        let id: String
        let gatewayId: String
        let energyLeft: Double
        let totalPackEnergy: Double
        let percentageCharged: Double
        let batteryType: String
        let backupCapable: Bool
        let batteryPower: Double
        let syncGridAlertEnabled: Bool
        let breakerAlertEnabled: Bool
    }

    fileprivate struct Response: Decodable {
        let response: [TeslaProduct]
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

    fileprivate struct AnyProduct: TeslaProduct, Decodable {
        let product: TeslaProduct

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
                throw Error.decoding("Unsupported product type")
            }
        }
    }

}

protocol TeslaProduct {}
