//
//  TeslaApi+requestToken.swift
//  TeslaApi
//
//  Created by peter bohac on 4/12/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Combine
import Foundation

extension TeslaApi {

    func exchangeToken(_ oauthToken: String) -> AnyPublisher<Token, Swift.Error> {
        let request: URLRequest = {
            var request = URLRequest(url: URL(string: "/oauth/token", relativeTo: Constants.baseUri)!)
            request.httpMethod = Constants.Method.post
            request.httpBody = try? Request.encoder.encode(Request())
            request.addValue(Constants.jsonContent, forHTTPHeaderField: Constants.contentType)
            request.addValue(String(format: Constants.authorisationValue, oauthToken), forHTTPHeaderField: Constants.authorisationKey)
            return request
        }()

        return urlSession.dataTaskPublisher(for: request)
            .tryMap(Self.validateResponse)
            .decode(type: ApiTokenResponse.self, decoder: ApiTokenResponse.decoder)
            .map(Token.init)
            .handleEvents(receiveOutput: { token in self.currentToken = token })
            .eraseToAnyPublisher()
    }

    fileprivate struct Request: Encodable {
        let grantType = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        let clientId = Constants.clientId
        let clientSecret = Constants.clientSecret

        static let encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            return encoder
        }()
    }
}
