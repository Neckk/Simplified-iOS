////
////  CleverLoginViewController.swift
////  Simplified
////
////  Created by Aferdita Muriqi on 8/13/16.
////  Copyright © 2016 NYPL Labs. All rights reserved.
////
//
//import UIKit
//import WebKit
//
//typealias CompletionHandler = () -> Void
//
//class CleverLoginViewController: UIViewController, WKNavigationDelegate {
//
//    var libraryAccountID: String!
//    private let permissionsCheckLock = NSLock()
//
//    @objc var libraryAccount: Account? {
//        guard let libraryAccountID = libraryAccountID else { return nil }
//        return AccountsManager.shared.account(libraryAccountID)
//    }
//
//    @objc var userAccount: NYPLUserAccount {
//        return NYPLUserAccount.sharedAccount(libraryUUID: libraryAccountID)
//    }
//
//    var cleverAuth:(authToken:String,patron:AnyObject,adobeToken:String)?
//    var completionHandler:CompletionHandler!
//
//    let instructionLabel = UILabel()
//
//    let activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        self.view.backgroundColor = UIColor.white
//
//        self.view.addSubview(self.instructionLabel)
//        self.instructionLabel.textColor = UIColor.gray
//        self.instructionLabel.text =
//            NSLocalizedString("Log in with Safari to continue.",
//                              comment: "An instruction for the user to log into Clever via Safari.")
//        self.instructionLabel.sizeToFit()
//
//        let cancelBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(CleverLoginViewController.didSelectCancel))
//
//        self.navigationItem.leftBarButtonItem = cancelBarButtonItem
//        self.navigationController?.navigationBar.barStyle = .default
//        self.navigationController?.navigationBar.isTranslucent = false
//
//        let url = NYPLUserAccount.sharedAccount().adobeToken
//
//        var urlComponents = URLComponents()
//        urlComponents.scheme = url.scheme;
//        urlComponents.host = url.host;
//        urlComponents.path = url.path;
//
//        // add params
//        let provider = URLQueryItem(name: "provider", value: "Clever")
//        let redirect_uri = URLQueryItem(name: "redirect_uri", value: "open-ebooks-clever://oauth")
//        urlComponents.queryItems = [provider, redirect_uri]
//
//        NotificationCenter.default.addObserver(
//            forName: NSNotification.Name.NYPLAppDelegateDidReceiveCleverRedirectURL,
//            object: nil,
//            queue: OperationQueue.main,
//            using: { notification in self.handleRedirectURL(url: notification.object as! URL) })
//
//
//        UIApplication.shared.openURL(urlComponents.url!)
//    }
//
//    deinit {
//        NotificationCenter.default.removeObserver(self)
//    }
//
//    override func viewWillLayoutSubviews() {
//        self.instructionLabel.centerInSuperview();
//        self.instructionLabel.integralizeFrame();
//    }
//
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//    }
//
//    func handleRedirectURL(url: URL) {
//
//        self.navigationItem.leftBarButtonItem?.isEnabled = false
//
//        LoadingIndicatorView.show(
//            self.view,
//            loadingText: NSLocalizedString("Logging in, please wait…",
//                                           comment: "An instruction to wait while a Clever login is being finalized."))
//
//        if(!url.absoluteString.hasPrefix("open-ebooks-clever")
//            || !(url.absoluteString.contains("error") || url.absoluteString.contains("access_token")))
//        {
//            // The server did not give us what we expected (e.g. we received a 500),
//            // thus we show an error message and stop handling the result.
//            self.showErrorMessage(nil)
//            return
//        }
//
//        let fragment = url.fragment
//        var kvpairs:[String:String] = [String:String]()
//        let components = fragment?.components(separatedBy: "&")
//        for component in components!
//        {
//            var kv = component.components(separatedBy: "=")
//            if kv.count == 2
//            {
//                kvpairs[kv[0]] = kv[1]
//            }
//        }
//
//        if let error = kvpairs["error"]
//        {
//            if let errorJson = error.replacingOccurrences(of: "+", with: " ").removingPercentEncoding?.parseJSONString
//            {
//                debugPrint(errorJson)
//
//                self.showErrorMessage((errorJson as? [String : Any])?["title"] as? String)
//
//            }
//        }
//
//        if let auth_token = kvpairs["access_token"],
//            let patron_info = kvpairs["patron_info"]
//        {
//            if let patronJson = patron_info.replacingOccurrences(of: "+", with: " ").removingPercentEncoding?.parseJSONString
//            {
//                var request = URLRequest(url: NYPLConfiguration.circulationURL().appendingPathComponent("AdobeAuth/authdata"))
//                request.httpMethod = "GET"
//                request.setValue("Bearer \(auth_token)", forHTTPHeaderField: "Authorization")
//
//                let dataTask = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
//                    if let stringData = data
//                    {
//                        if let adobe_token:String = NSString(data: stringData, encoding: String.Encoding.utf8.rawValue) as String?
//                        {
//                            self.cleverAuth = (auth_token,patronJson,adobe_token)
//
//                            debugPrint(auth_token)
//                            debugPrint(adobe_token)
//                            debugPrint(patronJson)
//
//                            self.validateCredentials()
//                        }
//                    }
//                })
//                dataTask.resume()
//            }
//        }
//    }
//
//    @objc func didSelectCancel()
//    {
//        self.dismiss(animated: true, completion: nil)
//    }
//
//    func showErrorMessage(_ message: String?)
//    {
//        let title = NSLocalizedString(
//            "Clever Sign-In Failed",
//            comment: "An alert title telling the user that signing into Clever failed.")
//
//        let message = message != nil ? message : NSLocalizedString("UnknownRequestError", comment: "")
//
//        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel, handler: nil))
//
//        self.dismiss(animated: true) {
//            NYPLRootTabBarController.shared()?.safelyPresentViewController(alert, animated: true, completion: nil)
//        }
//    }
//
//
//
//    func validateCredentials()
//    {
//        if let authToken = self.cleverAuth?.authToken,
//            let adobeToken = self.cleverAuth?.adobeToken
//        {
//            var request = URLRequest(url: NYPLConfiguration.loanURL())
//            request.httpMethod = "HEAD"
//            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
//
//            let dataTask = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, responseError) in
//
//                #if FEATURE_DRM_CONNECTOR
//                NYPLADEPT.sharedInstance().authorize(withVendorID: "OEI", username: adobeToken, password: "", completion: { (success, error) in
//                    self.authorizationAttemptDidFinish(success, error: error)
//                })
//                #else
//                self.authorizationAttemptDidFinish(true, error: nil)
//                #endif
//
//            })
//            dataTask.resume()
//        }
//    }
//
//    func authorizationAttemptDidFinish(_ success:Bool, error:Error?)
//    {
//
//        OperationQueue.main.addOperation {
//
//            if success
//            {
//                if let adobeToken = self.cleverAuth?.adobeToken,
//                    let patron = self.cleverAuth?.patron as? [AnyHashable: Any],
//                    let authToken = self.cleverAuth?.authToken
//                {
//                    NYPLAccount.shared().setAdobeToken(adobeToken, patron: patron)
//                    NYPLAccount.shared().setAuthToken(authToken)
//                    NYPLAccount.shared().setProvider(NSLocalizedString("Clever", comment: ""))
//
//                    self.dismiss(animated: false, completion: nil)
//
//                    let handler = self.completionHandler
//                    self.completionHandler = nil;
//                    if(handler != nil)
//                    {
//                        handler!()
//                    }
//
//                    NYPLBookRegistry.shared().sync(completionHandler: nil)
//
//                    OperationQueue.main.addOperation({
//                        NotificationCenter.default.post(name: Notification.Name(rawValue: NYPLAccountLoginDidChangeNotification), object: self)
//                    })
//
//                }
//            }
//        }
//    }
//
//
//    @objc class func loginWith(libraryAccountID: String, completionHandler: @escaping CompletionHandler)
//    {
//
//        let controller = CleverLoginViewController()
//        controller.libraryAccountID = libraryAccountID
//
//        controller.completionHandler = completionHandler
//
//        let viewController = UINavigationController(rootViewController: controller)
//
//        viewController.modalPresentationStyle = .formSheet;
//
//        NYPLRootTabBarController.shared()?.safelyPresentViewController(viewController, animated: true, completion: nil)
//    }
//
//}
//
//extension String {
//
//    var parseJSONString: AnyObject? {
//
//        let data = self.data(using: String.Encoding.utf8, allowLossyConversion: false)
//
//        if let jsonData = data {
//            // Will return an object or nil if JSON decoding fails
//            return try! JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject?
//        } else {
//            // Lossless conversion of the string was not possible
//            return nil
//        }
//    }
//}
