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
  let loginCancelHandler: (() -> Void)?
  let bookFoundHandler: ((URLRequest?, [HTTPCookie]) -> Void)?
  let problemFound: (((NYPLProblemDocument?)) -> Void)?
  let autoPresentIfNeeded: Bool

  init(cookies: [HTTPCookie], request: URLRequest, loginCompletionHandler: ((URL, [HTTPCookie]) -> Void)?, loginCancelHandler: (() -> Void)?, bookFoundHandler: ((URLRequest?, [HTTPCookie]) -> Void)?, problemFoundHandler: ((NYPLProblemDocument?) -> Void)?, autoPresentIfNeeded: Bool = false) {
    self.cookies = cookies
    self.request = request
    self.loginCompletionHandler = loginCompletionHandler
    self.loginCancelHandler = loginCancelHandler
    self.bookFoundHandler = bookFoundHandler
    self.problemFound = problemFoundHandler
    self.autoPresentIfNeeded = autoPresentIfNeeded
    super.init()
  }
}

@objcMembers
class NYPLCookiesWebViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
  private let uuid: String = UUID().uuidString
  private static var automaticBrowserStroage: [String: NYPLCookiesWebViewController] = [:]
  var model: CookiesWebViewModel! // must be set before view loads
  private var cookies: [String: HTTPCookie] = [:] // "domain+cookiename" is a key, use for ios < 11 only
  private var rawCookies: [HTTPCookie] {
     // use for ios < 11 only
    cookies.map { $0.value }
  }
  private let webView = WKWebView()
  private var previousRequest: URLRequest?

  init() {
    super.init(nibName: nil, bundle: nil)

    webView.configuration.preferences.javaScriptEnabled = true
    let cookieOutScript = WKUserScript(source: "window.webkit.messageHandlers.updateCookies.postMessage(document.cookie);", injectionTime: .atDocumentStart, forMainFrameOnly: false)
    webView.configuration.userContentController.addUserScript(cookieOutScript)
    webView.configuration.userContentController.add(self, name: "updateCookies")

//    webView.configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
//    webView.configuration.websiteDataStore = WKWebsiteDataStore.default()
  }

  init(model: CookiesWebViewModel) {
    self.model = model
    super.init(nibName: nil, bundle: nil)

    let cookieOutScript = WKUserScript(source: "window.webkit.messageHandlers.updateCookies.postMessage(document.cookie);", injectionTime: .atDocumentStart, forMainFrameOnly: false)
    webView.configuration.userContentController.addUserScript(cookieOutScript)
    webView.configuration.userContentController.add(self, name: "updateCookies")

//    webView.configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
//    webView.configuration.websiteDataStore = WKWebsiteDataStore.default()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    view = webView
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    if model.autoPresentIfNeeded {
      NYPLCookiesWebViewController.automaticBrowserStroage[uuid] = self
    }

    navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""), style: .plain, target: self, action: #selector(didSelectCancel))

    webView.navigationDelegate = self
    if !model.cookies.isEmpty {
      var cookiesLeft = model.cookies.count
      for cookie in model.cookies {
        if #available(iOS 11.0, *) {
          webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) { [model, webView] in
            cookiesLeft -= 1
            if cookiesLeft == 0, let request = model?.request {
              webView.load(request)
            }
          }
        } else {
          // Fallback on earlier versions
          // load cookies in request for old iOSes
          self.cookies[cookie.domain + cookie.name] = cookie

          cookiesLeft -= 1
          if cookiesLeft == 0, let request = model?.request {
            loadWebPage(request: request)
          }
        }
      }
    } else {
      webView.load(model.request)
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    NYPLCookiesWebViewController.automaticBrowserStroage[uuid] = nil
  }

  @objc private func didSelectCancel() {
    (navigationController?.presentingViewController ?? presentingViewController)?.dismiss(animated: true, completion: { [model] in model?.loginCancelHandler?() })
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

    previousRequest = navigationAction.request

    webView.evaluateJavaScript("document.cookie") { (result, error) in
      print("TestString script inline \(navigationAction.request.url?.absoluteString) \(result) \(error)")
    }

    if let loginHandler = model.loginCompletionHandler {
      // if want to receive a login callback
      if let destination = navigationAction.request.url, destination.absoluteString.hasPrefix("https://skyneck.pl/login") {
        // if login finished

        decisionHandler(.cancel)

        if #available(iOS 11.0, *) {
          webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [uuid, unowned self] (cookies) in
            loginHandler(destination, cookies)
            NYPLCookiesWebViewController.automaticBrowserStroage[uuid] = nil
          }
        } else {
          loginHandler(destination, rawCookies)
          NYPLCookiesWebViewController.automaticBrowserStroage[uuid] = nil
        }

        return
      }
    }

    if #available(iOS 11.0, *) { } else {
      let isCustomRequest = navigationAction.request.value(forHTTPHeaderField: "x-custom-header") != nil
      let domainCookies = rawCookies.filter { $0.domain == navigationAction.request.url?.host }

      if !isCustomRequest && !domainCookies.isEmpty {
        // if  already a custom request or there are no cookies to set - continue

        decisionHandler(.cancel)
        loadWebPage(request: navigationAction.request)
        return
      }
    }

    decisionHandler(.allow)
  }

  // use for ios < 11 only
  private func loadWebPage(request: URLRequest)  {
    var mutableRequest = request

    mutableRequest.setValue("true", forHTTPHeaderField: "x-custom-header")

    let headers = HTTPCookie.requestHeaderFields(with: rawCookies.filter { $0.domain == mutableRequest.url?.host })
    for (name, value) in headers {
      mutableRequest.addValue(value, forHTTPHeaderField: name)
    }

    webView.load(mutableRequest)
  }

  private var wasBookFound = false
  func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

    if let bookHandler = model.bookFoundHandler {
      // if want to receive a handle when book is found
      let supportedTypes = NYPLBookAcquisitionPath.supportedTypes()
      
      if let responseType = navigationResponse.response.mimeType, supportedTypes.contains(responseType) {
        decisionHandler(.cancel)
        wasBookFound = true

        if #available(iOS 11.0, *) {

          webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [uuid, weak self] cookies in
            bookHandler(self?.previousRequest, cookies)
            NYPLCookiesWebViewController.automaticBrowserStroage[uuid] = nil
            if self?.model.autoPresentIfNeeded == true {
              (self?.navigationController?.presentingViewController ?? self?.presentingViewController)?.dismiss(animated: true, completion: nil)
            }
          }
        } else {

          bookHandler(previousRequest, rawCookies)
          NYPLCookiesWebViewController.automaticBrowserStroage[uuid] = nil
          if model.autoPresentIfNeeded == true {
            (navigationController?.presentingViewController ?? presentingViewController)?.dismiss(animated: true, completion: nil)
          }

        }

        return
      }
    }

    if let problemHandler = model.problemFound {
      if let responseType = navigationResponse.response.mimeType, responseType == "application/problem+json" || responseType == "application/api-problem+json" {

        decisionHandler(.cancel)
        let presenter = navigationController?.presentingViewController ?? presentingViewController
        if let presentingVC = presenter, model.autoPresentIfNeeded {
          presentingVC.dismiss(animated: true, completion: { [uuid] in
            problemHandler(nil)
            NYPLCookiesWebViewController.automaticBrowserStroage[uuid] = nil
          })
        } else {
          problemHandler(nil)
          NYPLCookiesWebViewController.automaticBrowserStroage[uuid] = nil
        }

        return
      }
    }

    decisionHandler(.allow)
  }

  private var loginScreenHandlerOnceOnly = true
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

    if model.autoPresentIfNeeded {
      // delay is needed in case IDP will want to do a redirect after initial load (from within the page)
      OperationQueue.current?.underlyingQueue?.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let self = self else { return }
        guard !self.webView.isLoading else { return }
        guard !self.wasBookFound else { return }
        guard self.loginScreenHandlerOnceOnly else { return }
        self.loginScreenHandlerOnceOnly = false

        let navigationWrapper = UINavigationController(rootViewController: self)
        NYPLRootTabBarController.shared()?.safelyPresentViewController(navigationWrapper, animated: true, completion: nil)
        NYPLCookiesWebViewController.automaticBrowserStroage[self.uuid] = nil
      }
    }
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
//    let cookies: [String]? = (message.body as? String)?.components(separatedBy: "; ")
    print("TestString script callback \(message.body)")
//    for cookie in cookies {
//      let comps: [String] = cookie.components(separatedBy: "=")
//      if comps.count < 2 {
//        continue
//      }
//    }

  }
}

extension NYPLCookiesWebViewController: UIAdaptivePresentationControllerDelegate {
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    model?.loginCancelHandler?()
  }
}

extension WKWebView {
  func evaluate(script: String, completion: @escaping (_ result: AnyObject?, _ error: NSError?) -> Void) {
    var finished = false

    evaluateJavaScript(script) { (result, error) in
      if error == nil {
        if result != nil {
          completion(result as AnyObject?, nil)
        }
      } else {
        completion(nil, error as NSError?)
      }
      finished = true
    }

    while !finished {
      RunLoop.current.run(mode: .default, before: Date.distantFuture)
    }
  }
}
