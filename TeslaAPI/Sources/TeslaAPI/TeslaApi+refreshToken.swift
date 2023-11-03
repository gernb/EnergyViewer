//
//  TeslaApi+refreshToken.swift
//  TeslaApi
//
//  Created by peter bohac on 4/12/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Combine
import Foundation

extension TeslaApi {

    public func refreshToken() -> AnyPublisher<Token, Swift.Error> {
        return authToken(forceRefresh: true)
    }

    func refreshAuthToken(_ token: Token) -> AnyPublisher<Token, Swift.Error> {
        let request: URLRequest = {
            var request = URLRequest(url: URL(string: "/oauth2/v3/token", relativeTo: OAuthConstants.baseUri)!)
            request.httpMethod = Constants.Method.post
            request.httpBody = try? Request.encoder.encode(Request(refreshToken: token.refresh))
            request.addValue(Constants.jsonContent, forHTTPHeaderField: Constants.contentType)
            return request
        }()

        return urlSession.dataTaskPublisher(for: request)
            .tryMap(Self.validateResponse)
            .decode(type: ApiTokenResponse.self, decoder: ApiTokenResponse.decoder)
            .map(Token.init)
            .handleEvents(receiveOutput: { token in self.currentToken = token },
                          receiveCompletion: { _ in self.authQueue.sync { self.tokenRefreshPublisher = nil } })
            .eraseToAnyPublisher()
    }

    fileprivate struct Request: Encodable {
        let grantType = "refresh_token"
        let clientId = OAuthConstants.clientId
        let refreshToken: String
        let scope = "openid email offline_access"

        static let encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            return encoder
        }()
    }

    fileprivate enum OAuthConstants {
        static let baseUri = URL(string: "https://auth.tesla.com/")!
        static let clientId = "ownerapi"
    }

}
