//
//  TeslaApi.swift
//  TeslaApi
//
//  Created by peter bohac on 4/11/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Combine
import CryptoKit
import OAuthSwift
import WebKit

// Gleaned from: https://www.teslaapi.info
public protocol TeslaApiProviding {
    func requestToken() -> AnyPublisher<Token, Swift.Error>
    func refreshToken() -> AnyPublisher<Token, Swift.Error>
    func listProducts() -> AnyPublisher<[Product], Swift.Error>
    func liveStatus(for siteId: Int) -> AnyPublisher<SiteStatus, Swift.Error>
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
    var currentToken: Token?
    let authQueue = DispatchQueue(label: "TeslaApi.AuthenticationQueue")
    var tokenRefreshPublisher: AnyPublisher<Token, Swift.Error>?

    private var cancellables = Set<AnyCancellable>()
    private var oauthSwift: OAuth2Swift = {
        let oauthSwift = OAuth2Swift(
            consumerKey: "ownerapi",
            consumerSecret: Constants.clientSecret,
            authorizeUrl: "https://auth.tesla.com/oauth2/v3/authorize",
            accessTokenUrl: "https://auth.tesla.com/oauth2/v3/token",
            responseType: "code"
        )
        oauthSwift.authorizeURLHandler = WebViewController()
        return oauthSwift
    }()

    public init(urlSession: URLSession = URLSession.shared, token: Token? = nil) {
        self.urlSession = urlSession
        self.currentToken = token
    }

    public func requestToken() -> AnyPublisher<Token, Error> {
        let codeVerifier = Data(Constants.clientId.utf8)
            .compactMap { String(format: "%02x", $0) }
            .joined()
        let codeChallenge = SHA256.hash(data: Data(codeVerifier.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()

        return Future<OAuthSwift.TokenSuccess, OAuthSwiftError> { completion in
            self.oauthSwift.authorize(withCallbackURL: "https://auth.tesla.com/void/callback",
                                      scope: "openid email offline_access",
                                      state: "state",
                                      codeChallenge: codeChallenge,
                                      codeVerifier: codeVerifier,
                                      completionHandler: completion)
        }
        .mapError { error in
            print(error)
            return TeslaApiError.notLoggedIn
        }
        .flatMap { self.exchangeToken($0.credential.oauthToken) }
        .eraseToAnyPublisher()
    }

    func authToken(forceRefresh: Bool = false) -> AnyPublisher<Token, Swift.Error> {
        return authQueue.sync { [weak self] in
            if let publisher = self?.tokenRefreshPublisher {
                return publisher
            }

            guard let token = self?.currentToken else {
                return Fail(error: TeslaApiError.notLoggedIn).eraseToAnyPublisher()
            }

            if token.isValid && !forceRefresh {
                return Just(token)
                    .setFailureType(to: Swift.Error.self)
                    .eraseToAnyPublisher()
            }

            guard let publisher = self?.refreshAuthToken(token).share().eraseToAnyPublisher() else {
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
                // Refresh and retry (one time) on auth error
                return self.authToken(forceRefresh: true)
                    .flatMap(dataTaskPublisher)
                    .eraseToAnyPublisher()
            })
            .eraseToAnyPublisher()
    }

    static func validateResponse(data: Data, response: URLResponse) throws -> Data {
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

    private final class WebViewController: OAuthWebViewController, WKNavigationDelegate {
        let webView: WKWebView = {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
            let webView = WKWebView(frame: .zero, configuration: configuration)
            return webView
        }()

        override func viewDidLoad() {
            super.viewDidLoad()
            webView.navigationDelegate = self
            webView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(self.webView)
            webView.pinEdges(to: view)
        }

        override func handle(_ url: URL) {
            super.handle(url)
            let req = URLRequest(url: url)
            DispatchQueue.main.async {
                self.webView.load(req)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.absoluteString.hasPrefix("https://auth.tesla.com/void/callback") {
                decisionHandler(.cancel)
                self.dismissWebViewController()
                OAuthSwift.handle(url: url)
                return
            }
            decisionHandler(.allow)
        }
    }
}

fileprivate extension UIView {
    func pinEdges(to other: UIView) {
        leadingAnchor.constraint(equalTo: other.leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: other.trailingAnchor).isActive = true
        topAnchor.constraint(equalTo: other.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: other.bottomAnchor).isActive = true
    }
}
