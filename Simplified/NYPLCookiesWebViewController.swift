//
//  NYPLCookiesWebViewController.swift
//  SimplyE
//
//  Created by Jacek Szyja on 17/06/2020.
//  Copyright © 2020 NYPL Labs. All rights reserved.
//

import UIKit
import WebKit

@objcMembers
class CookiesWebViewModel: NSObject {
  let cookies: [HTTPCookie]
  let request: URLRequest
  let loginCompletionHandler: ((URL, [HTTPCookie]) -> Void)?
  let bookFoundHandler: ((URLRequest?, [HTTPCookie]) -> Void)?
  let loginScreenHandler: (() -> Void)?

  init(cookies: [HTTPCookie], request: URLRequest, loginCompletionHandler: ((URL, [HTTPCookie]) -> Void)?, bookFoundHandler: ((URLRequest?, [HTTPCookie]) -> Void)?, loginScreenHandler: (() -> Void)?) {
    self.cookies = cookies
    self.request = request
    self.loginCompletionHandler = loginCompletionHandler
    self.bookFoundHandler = bookFoundHandler
    self.loginScreenHandler = loginScreenHandler
    super.init()
  }
}

@objcMembers
class NYPLCookiesWebViewController: UIViewController, WKNavigationDelegate {
  private let model: CookiesWebViewModel // must be set before view loads
  private var domainCookies: [String: [HTTPCookie]] = [:]
  private let webView = WKWebView()
  private var previousRequest: URLRequest?

  init(model: CookiesWebViewModel) {
    self.model = model
    super.init(nibName: nil, bundle: nil)

    webView.configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    self.view = webView
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    webView.navigationDelegate = self
    if !model.cookies.isEmpty {
      var cookiesLeft = model.cookies.count
      for cookie in model.cookies {
        if #available(iOS 11.0, *) {
          webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) { [model, webView] in
            cookiesLeft -= 1
            if cookiesLeft == 0 {
              webView.load(model.request)
            }
          }
        } else {
          // Fallback on earlier versions
          // load cookies in old ios
        }
      }
    } else {
      webView.load(model.request)
    }
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

    previousRequest = navigationAction.request

    if let loginHandler = model.loginCompletionHandler {
      // if want to receive a login callback
      if #available(iOS 11.0, *) {
        if let destination = navigationAction.request.url, destination.absoluteString.hasPrefix("https://skyneck.pl/login") {
          decisionHandler(.cancel)

          webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [model, weak self] (cookies) in
            loginHandler(destination, cookies)
            return
          }

        } else {
          decisionHandler(.allow)
        }
      } else {
        if let destination = navigationAction.request.url?.absoluteString {
          if destination.hasPrefix("https://skyneck.pl/login") {
          }
        }

        decisionHandler(.allow)
      }
    } else {
      decisionHandler(.allow)
    }
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

    if let bookHandler = model.bookFoundHandler {
      // if want to receive a handle when book is found
      let supportedTypes = NYPLBookAcquisitionPath.supportedTypes()
      
      if let responseType = navigationResponse.response.mimeType, supportedTypes.contains(responseType) {

        if #available(iOS 11.0, *) {
          decisionHandler(.cancel)
          webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            bookHandler(self?.previousRequest, cookies)
            return
          }
        } else {
          decisionHandler(.allow)
        }

        return
      }
    }

    decisionHandler(.allow)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    if let loginHandler = model.loginScreenHandler {
      loginHandler()
    }
  }
}
