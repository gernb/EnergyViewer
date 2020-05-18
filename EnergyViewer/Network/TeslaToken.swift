//
//  TeslaToken.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/11/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation

public struct TeslaToken: Codable {
    let auth: String
    let refresh: String
    let validUntil: Date
}

extension TeslaApiNetworkModel {
    struct ApiTokenResponse: Decodable {
        let accessToken: String
        let tokenType: String
        let expiresIn: Double
        let refreshToken: String
        let createdAt: Date

        static let decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .secondsSince1970
            return decoder
        }()
    }
}

extension TeslaToken {
    init(response: TeslaApiNetworkModel.ApiTokenResponse) {
        self.init(auth: response.accessToken,
                  refresh: response.refreshToken,
                  validUntil: response.createdAt.addingTimeInterval(response.expiresIn))
    }
}
