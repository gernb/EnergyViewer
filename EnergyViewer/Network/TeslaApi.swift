//
//  TeslaApi.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/11/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import Combine

// Gleaned from: https://www.teslaapi.info
final class TeslaApi {
    enum Error: Swift.Error {
        case invalidResponse
        case httpUnauthorised
        case httpError(code: Int)
        case decoding(String)
    }

    let urlSession: URLSession
    var token: ApiToken?
    let tokenRefreshing = DispatchSemaphore(value: 1)

    init(urlSession: URLSession = URLSession.shared, token: ApiToken? = nil) {
        self.urlSession = urlSession
        self.token = token
    }

    func authoriseRequest(_ request: URLRequest) -> Future<URLRequest, Never> {
        return Future<URLRequest, Never> { promise in
            DispatchQueue.global().async {
                self.tokenRefreshing.wait()
                self.tokenRefreshing.signal()
                var request = request
                if let token = self.token {
                    let value = String(format: Constants.authorisationValue, token.auth)
                    request.addValue(value, forHTTPHeaderField: Constants.authorisationKey)
                }
                promise(.success(request))
            }
        }
    }

    func validateResponse(data: Data, response: URLResponse) throws -> Data {
        guard let response = response as? HTTPURLResponse else { throw Error.invalidResponse }
        if 200 ..< 300 ~= response.statusCode {
            return data
        } else if response.statusCode == 401{
            throw Error.httpUnauthorised
        } else {
            throw Error.httpError(code: response.statusCode)
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
