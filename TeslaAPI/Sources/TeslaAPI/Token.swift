//
//  Token.swift
//  TeslaApi
//
//  Created by peter bohac on 4/11/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation

public struct Token: Codable {
    public let auth: String
    public let refresh: String
    public let validUntil: Date

    public var isValid: Bool { validUntil > Date().addingTimeInterval(10) } // provide a 10 second "buffer"
}

extension TeslaApi {
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

extension Token {
    init(response: TeslaApi.ApiTokenResponse) {
        self.init(auth: response.accessToken,
                  refresh: response.refreshToken,
                  validUntil: response.createdAt.addingTimeInterval(response.expiresIn))
    }
}
