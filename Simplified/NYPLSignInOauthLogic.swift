//
//  NYPLSignInOauthLogic.swift
//  SimplyE
//
//  Created by Jacek Szyja on 20/05/2020.
//  Copyright © 2020 NYPL Labs. All rights reserved.
//

import Foundation

class NYPLSignInOauthLogic: NSObject {
    @objc var authToken: String?
    @objc var patronInfo: AnyObject?

    @objc func handleRedirectURL(url: URL) {

        if(!url.absoluteString.hasPrefix("https://skyneck.pl/login")
            || !(url.absoluteString.contains("error") || url.absoluteString.contains("access_token")))
        {
            // The server did not give us what we expected (e.g. we received a 500),
            // thus we show an error message and stop handling the result.

            //            self.showErrorMessage(nil)
            return
        }

        let fragment = url.fragment
        let kvpairs:[String:String] = fragment?
            .components(separatedBy: "&")
            .map({ $0.components(separatedBy: "=") })
            .filter { $0.count == 2 }
            .reduce(into: [String: String](), { (allPairs, newPair) in
                allPairs[newPair[0]] = newPair[1]
            }) ?? [:]

        if
            let error = kvpairs["error"],
            let errorJson = error.replacingOccurrences(of: "+", with: " ").removingPercentEncoding?.parseJSONString
        {
                debugPrint(errorJson)
//                self.showErrorMessage((errorJson as? [String : Any])?["title"] as? String)
        }

        if
            let auth_token = kvpairs["access_token"],
            let patron_info = kvpairs["patron_info"],
            let patronJson = patron_info.replacingOccurrences(of: "+", with: " ").removingPercentEncoding?.parseJSONString
        {
            self.authToken = auth_token
            self.patronInfo = patronJson
//                [self validateCredentials];
        }
    }

}

extension NSString {

    @objc var parseJSONString: AnyObject? {

        let data = self.data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)

        if let jsonData = data {
            // Will return an object or nil if JSON decoding fails
            return try! JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject?
        } else {
            // Lossless conversion of the string was not possible
            return nil
        }
    }
}
