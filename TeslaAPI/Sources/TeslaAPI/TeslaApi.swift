//
//  TeslaApi.swift
//  TeslaApi
//
//  Created by peter bohac on 4/11/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Combine
import Foundation
import OSLog

extension Logger {
    static let `default` = Self(subsystem: "TeslaApi", category: "default")
}

// Gleaned from: https://tesla-api.timdorr.com/
public protocol TeslaApiProviding {
    func requestToken() -> AnyPublisher<Token, Swift.Error>
    func refreshToken() -> AnyPublisher<Token, Swift.Error>
    func listProducts() -> AnyPublisher<[Product], Swift.Error>
    func liveStatus(for siteId: Int) -> AnyPublisher<LiveStatus, Swift.Error>
    func siteStatus(for siteId: Int) -> AnyPublisher<SiteStatus, Swift.Error>
    func powerHistory(for siteId: Int, endDate: Date?) -> AnyPublisher<PowerHistory, Swift.Error>
    func energyHistory(for siteId: Int, period: TimePeriod, endDate: Date?) -> AnyPublisher<EneryHistory, Swift.Error>
    func selfConsumptionHistory(for siteId: Int, period: TimePeriod, endDate: Date?) -> AnyPublisher<SelfConsumptionHistory, Swift.Error>
}

public enum TeslaApiError: Swift.Error, Equatable {
    case notLoggedIn
    case invalidResponse
    case httpUnauthorised
    case httpError(code: Int)
    case decoding(String)
}

public final class TeslaApi: TeslaApiProviding {
    let urlSession: URLSession
    var currentToken: Token? {
        didSet {
            didUpdateToken(currentToken)
        }
    }
    let authQueue = DispatchQueue(label: "TeslaApi.AuthenticationQueue")
    var tokenRefreshPublisher: AnyPublisher<Token, Swift.Error>?
    let didUpdateToken: (Token?) -> Void

    public init(urlSession: URLSession = URLSession.shared, token: Token? = nil, onDidUpdateToken: @escaping (Token?) -> Void = { _ in }) {
        self.urlSession = urlSession
        self.currentToken = token
        self.didUpdateToken = onDidUpdateToken
    }

    func authToken(forceRefresh: Bool = false) -> AnyPublisher<Token, Swift.Error> {
        return authQueue.sync { [weak self] in
            if let publisher = self?.tokenRefreshPublisher {
                return publisher
            }

            guard let token = self?.currentToken else {
                Logger.default.error("[authToken()] self is nil or no currentToken")
                return Fail(error: TeslaApiError.notLoggedIn).eraseToAnyPublisher()
            }

            if token.isValid && !forceRefresh {
                return Just(token)
                    .setFailureType(to: Swift.Error.self)
                    .eraseToAnyPublisher()
            }

            guard let publisher = self?.refreshAuthToken(token).share().eraseToAnyPublisher() else {
                Logger.default.error("[authToken()] self is nil or unable to get refreshAuthToken publisher")
                return Fail(error: TeslaApiError.notLoggedIn).eraseToAnyPublisher() // TODO: this is prolly not the ideal error here
            }
            self?.tokenRefreshPublisher = publisher
            return publisher
        }
    }

    func authenticateAndPerform(request: URLRequest) -> AnyPublisher<Data, Swift.Error> {
        let dataTaskPublisher = { [urlSession] (token: Token) -> AnyPublisher<Data, Swift.Error> in
            var request = request
            let value = String(format: Constants.authorisationValue, token.auth)
            request.addValue(value, forHTTPHeaderField: Constants.authorisationKey)
            return urlSession.dataTaskPublisher(for: request)
                .tryMap(Self.validateResponse)
                .eraseToAnyPublisher()
        }
        return authToken()
            .flatMap(dataTaskPublisher)
            .tryCatch({ error -> AnyPublisher<Data, Swift.Error> in
                guard (error as? TeslaApiError) == .httpUnauthorised else { throw error }
                Logger.default.info("[authenticateAndPerform] received httpUnauthorised; retrying...")
                // Refresh and retry (one time) on auth error
                return self.authToken(forceRefresh: true)
                    .flatMap(dataTaskPublisher)
                    .eraseToAnyPublisher()
            })
            .eraseToAnyPublisher()
    }

    static func validateResponse(data: Data, response: URLResponse) throws -> Data {
        guard let response = response as? HTTPURLResponse else {
            Logger.default.warning("[validateResponse] received invalid response")
            throw TeslaApiError.invalidResponse
        }
        if 200 ..< 300 ~= response.statusCode {
            return data
        } else if response.statusCode == 401 {
            Logger.default.warning("[validateResponse] received error code 401 (unauthorized)")
            throw TeslaApiError.httpUnauthorised
        } else {
            Logger.default.warning("[validateResponse] received error code \(response.statusCode, privacy: .public)")
            throw TeslaApiError.httpError(code: response.statusCode)
        }
    }

    enum Constants {
        static let baseUri = URL(string: "https://owner-api.teslamotors.com/")!
        static let contentType = "Content-Type"
        static let jsonContent = "application/json"
        static let authorisationKey = "Authorization"
        static let authorisationValue = "Bearer %@"

        enum Method {
            static let post = "POST"
        }

        static let clientSecret = "c7257eb71a564034f9419ee651c7d0e5f7aa6bfbd18bafb5c5c033b093bb2fa3"
        static let clientId = "81527cff06843c8634fdc09e8ac0abefb46ac849f38fe1e431c2ef2106796384"
    }
}
