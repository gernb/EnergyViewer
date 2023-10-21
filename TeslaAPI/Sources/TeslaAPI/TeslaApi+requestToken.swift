//
//  TeslaApi+requestToken.swift
//  TeslaApi
//
//  Created by peter bohac on 4/12/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Combine
import Foundation
import UIKit
import WebKit

extension TeslaApi {
    public func requestToken() -> AnyPublisher<Token, Error> {
        let url: URL = {
            let url = URL(string: "/oauth2/v3/authorize", relativeTo: OAuthConstants.baseUri)!
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: OAuthConstants.clientId),
                URLQueryItem(name: "redirect_uri", value: OAuthConstants.redirectUri),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: "openid email offline_access")
            ]
            return components.url!
        }()
        let webView = WebViewController()

        return Future<URL, Swift.Error> { promise in
            webView.present(url, completion: promise)
        }
        .tryMap { url in
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                throw TeslaApiError.notLoggedIn
            }
            return code
        }
        .flatMap(convertCode)
        .eraseToAnyPublisher()
    }

    fileprivate enum OAuthConstants {
        static let baseUri = URL(string: "https://auth.tesla.com/")!
        static let redirectUri = "https://auth.tesla.com/void/callback"
        static let clientId = "ownerapi"
    }

    fileprivate func convertCode(_ code: String) -> AnyPublisher<Token, Swift.Error> {
        let request: URLRequest = {
            var request = URLRequest(url: URL(string: "/oauth2/v3/token", relativeTo: OAuthConstants.baseUri)!)
            request.httpMethod = Constants.Method.post
            request.httpBody = try? ConvertCodeRequest.encoder.encode(ConvertCodeRequest(code: code))
            request.addValue(Constants.jsonContent, forHTTPHeaderField: Constants.contentType)
            return request
        }()

        return urlSession.dataTaskPublisher(for: request)
            .tryMap(Self.validateResponse)
            .decode(type: ApiTokenResponse.self, decoder: ApiTokenResponse.decoder)
            .map(Token.init)
            .handleEvents(receiveOutput: {
                self.currentToken = $0
            })
            .eraseToAnyPublisher()
    }

    fileprivate struct ConvertCodeRequest: Encodable {
        let grantType = "authorization_code"
        let clientId = OAuthConstants.clientId
        let code: String
        let codeVerifier = Constants.clientId
        let redirectUri = OAuthConstants.redirectUri

        static let encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            return encoder
        }()
    }

    fileprivate final class WebViewController: UIViewController, WKNavigationDelegate {
        lazy var webView: WKWebView = {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = self
            return webView
        }()
        private var completion: ((Result<URL, Swift.Error>) -> Void)?

        override func loadView() {
            view = webView
        }

        func present(_ url: URL, completion: @escaping (Result<URL, Swift.Error>) -> Void) {
            self.completion = completion
            let req = URLRequest(url: url)
            DispatchQueue.main.async {
                UIApplication.shared.windows.first?.rootViewController?.present(self, animated: true)
                self.webView.load(req)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.absoluteString.hasPrefix(OAuthConstants.redirectUri) {
                decisionHandler(.cancel)
                completion?(.success(url))
                dismiss(animated: true)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            completion?(.failure(TeslaApiError.notLoggedIn))
            dismiss(animated: true)
        }
    }
}
