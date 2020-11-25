//
//  TeslaApi+requestToken.swift
//  TeslaApi
//
//  Created by peter bohac on 4/12/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import Combine

extension TeslaApi {

    public func requestToken(for email: String, password: String) -> AnyPublisher<Token, Swift.Error> {
        let request: URLRequest = {
            var request = URLRequest(url: URL(string: "/oauth/token", relativeTo: Constants.baseUri)!)
            request.httpMethod = Constants.Method.post
            request.httpBody = try? Request.encoder.encode(Request(email: email, password: password))
            request.addValue(Constants.jsonContent, forHTTPHeaderField: Constants.contentType)
            return request
        }()

        return urlSession.dataTaskPublisher(for: request)
            .tryMap(validateResponse)
            .decode(type: ApiTokenResponse.self, decoder: ApiTokenResponse.decoder)
            .map(Token.init)
            .handleEvents(receiveOutput: { token in self.currentToken = token })
            .eraseToAnyPublisher()
    }

    fileprivate struct Request: Encodable {
        let grantType = "password"
        let clientId = Constants.clientId
        let clientSecret = Constants.clientSecret
        let email: String
        let password: String

        static let encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            return encoder
        }()
    }

}
