//
//  TeslaApi.swift
//  TeslaApi
//
//  Created by peter bohac on 4/11/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Combine
import Foundation

// Gleaned from: https://www.teslaapi.info
public protocol TeslaApiProviding {
    func requestToken(for email: String, password: String) -> AnyPublisher<Token, Swift.Error>
    func refreshToken() -> AnyPublisher<Token, Swift.Error>
    func listProducts() -> AnyPublisher<[Product], Swift.Error>
    func liveStatus(for siteId: Int) -> AnyPublisher<SiteStatus, Swift.Error>
    func powerHistory(for siteId: Int, endDate: Date?) -> AnyPublisher<[TimePeriodPower], Swift.Error>
    func energyHistory(for siteId: Int, period: TimePeriod, endDate: Date?) -> AnyPublisher<[TimePeriodEnergy], Swift.Error>
    func selfConsumptionHistory(for siteId: Int, period: TimePeriod, endDate: Date?) -> AnyPublisher<[SelfConsumptionEnergy], Swift.Error>
}

public enum TeslaApiError: Swift.Error {
    case invalidResponse
    case httpUnauthorised
    case httpError(code: Int)
    case decoding(String)
}

public final class TeslaApi: TeslaApiProviding {
    let urlSession: URLSession
    var token: Token?
    let tokenRefreshing = DispatchSemaphore(value: 1)

    public init(urlSession: URLSession = URLSession.shared, token: Token? = nil) {
        self.urlSession = urlSession
        self.token = token
    }

    func authoriseRequest(_ request: URLRequest) -> Future<URLRequest, URLError> {
        return Future { [weak self] promise in
            DispatchQueue.global().async {
                guard let strongSelf = self else {
                    promise(.success(request))
                    return
                }
                strongSelf.tokenRefreshing.wait()
                strongSelf.tokenRefreshing.signal()
                var request = request
                if let token = strongSelf.token {
                    let value = String(format: Constants.authorisationValue, token.auth)
                    request.addValue(value, forHTTPHeaderField: Constants.authorisationKey)
                }
                promise(.success(request))
            }
        }
    }

    func validateResponse(data: Data, response: URLResponse) throws -> Data {
        guard let response = response as? HTTPURLResponse else { throw TeslaApiError.invalidResponse }
        if 200 ..< 300 ~= response.statusCode {
            return data
        } else if response.statusCode == 401 {
            throw TeslaApiError.httpUnauthorised
        } else {
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
