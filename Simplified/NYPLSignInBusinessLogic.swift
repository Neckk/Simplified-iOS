//
//  NYPLSignInBusinessLogic.swift
//  Simplified
//
//  Created by Ettore Pasquini on 5/5/20.
//  Copyright © 2020 NYPL Labs. All rights reserved.
//

import UIKit

class NYPLSignInBusinessLogic: NSObject {

  @objc let libraryAccountID: String
  private let permissionsCheckLock = NSLock()

    @objc var isCurrentlySigningIn: Bool = false
    @objc var session: URLSession!

  private var authToken: String?
  private var patronInfo: AnyObject?

  @objc init(libraryAccountID: String) {
    self.libraryAccountID = libraryAccountID
    super.init()
  }

  @objc var libraryAccount: Account? {
    return AccountsManager.shared.account(libraryAccountID)
  }

  @objc var userAccount: NYPLUserAccount {
    return NYPLUserAccount.sharedAccount(libraryUUID: libraryAccountID)
  }

  @objc func librarySupportsBarcodeDisplay() -> Bool {
    // For now, only supports libraries granted access in Accounts.json,
    // is signed in, and has an authorization ID returned from the loans feed.
    return userAccount.hasBarcodeAndPIN() &&
      userAccount.authorizationIdentifier != nil &&
      (libraryAccount?.details?.supportsBarcodeDisplay ?? false)
  }

  @objc func isSignedIn() -> Bool {
    return userAccount.hasCredentials()
  }

  @objc func registrationIsPossible() -> Bool {
    return !isSignedIn() && NYPLConfiguration.cardCreationEnabled() && libraryAccount?.details?.signUpUrl != nil
  }

  @objc func juvenileCardsManagementIsPossible() -> Bool {
    guard NYPLConfiguration.cardCreationEnabled() else {
      return false
    }
    guard libraryAccount?.details?.supportsCardCreator ?? false else {
      return false
    }

    return isSignedIn()
  }

  @objc func shouldShowEULALink() -> Bool {
    return libraryAccount?.details?.getLicenseURL(.eula) != nil
  }

  @objc func shouldShowSyncButton() -> Bool {
    guard let libraryDetails = libraryAccount?.details else {
      return false
    }

    return libraryDetails.supportsSimplyESync &&
      libraryDetails.getLicenseURL(.annotations) != nil &&
      userAccount.hasCredentials() &&
      libraryAccountID == AccountsManager.shared.currentAccount?.uuid
  }

  /// Updates server sync setting for the currently selected library.
  /// - Parameters:
  ///   - granted: Whether the user is granting sync permission or not.
  ///   - postServerSyncCompletion: Only run when granting sync permission.
  @objc func changeSyncPermission(to granted: Bool,
                                  postServerSyncCompletion: @escaping (Bool) -> Void) {
    if granted {
      // When granting, attempt to enable on the server.
      NYPLAnnotations.updateServerSyncSetting(toEnabled: true) { success in
        self.libraryAccount?.details?.syncPermissionGranted = success
        postServerSyncCompletion(success)
      }
    } else {
      // When revoking, just ignore the server's annotations.
      libraryAccount?.details?.syncPermissionGranted = false
    }
  }


  /// Checks with the annotations sync status with the server, adding logic
  /// to make sure only one such requests is being executed at a time.
  /// - Parameters:
  ///   - preWork: Any preparatory work to be done. This block is run
  ///   synchronously on the main thread. It's not run at all if a request is
  ///   already ongoing or if the current library doesn't support syncing.
  ///   - postWork: Any final work to be done. This block is run
  ///   on the main thread. It's not run at all if a request is
  ///   already ongoing or if the current library doesn't support syncing.
  @objc func checkSyncPermission(preWork: () -> Void,
                                 postWork: @escaping (_ enableSync: Bool) -> Void) {
    guard let libraryDetails = libraryAccount?.details else {
      return
    }

    guard permissionsCheckLock.try(), libraryDetails.supportsSimplyESync else {
      Log.debug(#file, "Skipping sync setting check. Request already in progress or sync not supported.")
      return
    }

    NYPLMainThreadRun.sync {
      preWork()
    }

    NYPLAnnotations.requestServerSyncStatus(forAccount: userAccount) { enableSync in
      if enableSync {
        libraryDetails.syncPermissionGranted = true
      }

      NYPLMainThreadRun.sync {
        postWork(enableSync)
      }

      self.permissionsCheckLock.unlock()
    }
  }

    @objc func validateCredentials() {
        guard let profilePath = libraryAccount?.details?.userProfileUrl else { return }
        guard let profileURL = URL(string: profilePath) else { return }

        var request = URLRequest(url: profileURL)
        request.timeoutInterval = 20

        if
            libraryAccount?.details?.oauthIntermediaryUrl != nil,
            let authToken = self.authToken
        {
            let authenticationValue = "Bearer \(authToken)"
            request.addValue(authenticationValue, forHTTPHeaderField: "Authorization")
        }

        isCurrentlySigningIn = true

        let task = session.dataTask(with: request) { [weak self] (data, response, error) in
            self?.isCurrentlySigningIn = false
            if (response as? HTTPURLResponse)?.statusCode == 200 {
//#if FEATURE_DRM_CONNECTOR
                guard let data = data else { return }

                let pDoc: UserProfileDocument
                do {
                    pDoc = try UserProfileDocument.fromData(data)
                } catch {
                    NYPLErrorLogger.logUserProfileDocumentError(error: error as NSError)
//                    [self authorizationAttemptDidFinish:NO error:[NSError errorWithDomain:@"NYPLAuth" code:20 userInfo:@{ @"message":@"Error parsing user profile doc" }]]
                    return
                }

                if let authorizationID = pDoc.authorizationIdentifier {
                    NYPLUserAccount.sharedAccount().setAuthorizationIdentifier(authorizationID)
                } else {
//                    NYPLLOG(@"Authorization ID (Barcode String) was nil.")
                }

                guard let firstDrm = pDoc.drm?.first,
                    let clientToken = firstDrm.clientToken,
                    let vendor = firstDrm.vendor else {
//                        NYPLLOG(@"Login Failed: No Licensor Token received or parsed from user profile document");
//                        [self authorizationAttemptDidFinish:NO error:[NSError errorWithDomain:@"NYPLAuth" code:20 userInfo:@{ @"message":@"Trouble locating DRMs in profile doc" }]];

                        return
                }

                NYPLUserAccount.sharedAccount().setLicensor(firstDrm.licensor)

                var licensorItems = clientToken.replacingOccurrences(of: "\n", with: "").components(separatedBy: "|")
                let tokenPassword = licensorItems.popLast()
                let tokenUsername = licensorItems.joined(separator: "|")

                // szyjson is it the same as in vendor?
                let licensorVendor = NYPLUserAccount.sharedAccount().licensor?["vendor"]

//                NYPLLOG("***DRM Auth/Activation Attempt***");
//                NYPLLOG_F("\nLicensor: %@\n",pDoc.drm[0].licensor);
//                NYPLLOG_F("Token Username: %@\n",tokenUsername);
//                NYPLLOG_F("Token Password: %@\n",tokenPassword);

                let completion: (Bool, Error?, String?, String?) -> Void

                completion = { success, error, deviceID, userID in
                    OperationQueue.main.addOperation {
                        NSObject.cancelPreviousPerformRequests(withTarget: self)
                    }

//                    NYPLLOG_F(@"Activation Success: %@\n", success ? @"Yes" : @"No");
//                    NYPLLOG_F(@"Error: %@\n",error.localizedDescription);
//                    NYPLLOG_F(@"UserID: %@\n",userID);
//                    NYPLLOG_F(@"DeviceID: %@\n",deviceID);
//                    NYPLLOG(@"***DRM Auth/Activation Completion***");

                    if let userID = userID, let deviceID = deviceID, success {
                        OperationQueue.main.addOperation {
                            NYPLUserAccount.sharedAccount().setUserID(userID)
                            NYPLUserAccount.sharedAccount().setDeviceID(deviceID)
                        }
                    } else {
                        // szyjson is it the same as in self.currentAccount.name?
                        NYPLErrorLogger.logLocalAuthFailed(error: error as NSError?, libraryName: AccountsManager.shared.currentAccount?.name)
                    }

//                    [self authorizationAttemptDidFinish:success error:error];

                }

//                NYPLADEPT.sharedInstance().authorizeWithVendorID(licensorVendor, username:tokenUsername, password:tokenPassword, completion: completion)

//                [self performSelector:@selector(dismissAfterUnexpectedDRMDelay) withObject:self afterDelay:25];


//#else
////                [self authorizationAttemptDidFinish:YES error:nil];
//#endif

            }

        }
    }

    @objc func authorizationAttemptDidFinish(success: Bool, error: Error?) {
        OperationQueue.main.addOperation { [weak self] in
//            [self removeActivityTitle];
//            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
//            UIApplication.shared.endIgnoringInteractionEvents()

            if success {
                let oauthURL = AccountsManager.shared.currentAccount?.details?.oauthIntermediaryUrl
                if
                    let authToken = self?.authToken,
                    let patron = self?.patronInfo as? [String: Any],
                    oauthURL != nil
                {
                    NYPLUserAccount.sharedAccount().setAuthToken(authToken)
                    NYPLUserAccount.sharedAccount().setPatron(patron)
                } else {
                    NYPLUserAccount.sharedAccount().setBarcode(<#T##barcode: String##String#>, PIN: <#T##String#>)
                }
            }
        }
    }
}
