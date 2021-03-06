import Foundation

@objcMembers final class AgeCheck : NSObject {
  // Static methods and vars
  static let sharedInstance = AgeCheck()

  @objc class func shared() -> AgeCheck
  {
    return AgeCheck.sharedInstance
  }
  

  // Members
  let serialQueue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier!).ageCheck")
  var handlerList = [((Bool) -> ())]()
  var isPresenting = false

  func verifyCurrentAccountAgeRequirement(_ completion: ((Bool) -> ())?) -> Void
  {
    serialQueue.async {
      guard let accountDetails = AccountsManager.shared.currentAccount?.details else {
        completion?(false)
        return
      }
      
      if accountDetails.needsAuth == true || accountDetails.userAboveAgeLimit {
        completion?(true)
        return
      }
      
      if !accountDetails.userAboveAgeLimit && NYPLSettings.shared.userPresentedAgeCheck {
        completion?(false)
        return
      }
      
      // We're already presenting the dialog, so queue the callback
      if self.isPresenting {
        if let completion = completion {
          self.handlerList.append(completion)
        }
        return
      }
      
      // Perform alert presentation
      self.isPresenting = true
      self.presentAgeVerificationView { over13 in
        NYPLSettings.shared.userPresentedAgeCheck = true
        if (over13) {
          accountDetails.userAboveAgeLimit = true
          completion?(true)
        } else {
          accountDetails.userAboveAgeLimit = false
          completion?(false)
        }

        self.isPresenting = false
        
        // Resolve queued callbacks
        self.serialQueue.async {
          for handler in self.handlerList {
            handler(accountDetails.userAboveAgeLimit)
          }
          self.handlerList.removeAll()
        }
      }
    }
  }
  
  fileprivate func presentAgeVerificationView(_ completion: @escaping (Bool) -> ()) -> Void
  {
    DispatchQueue.main.async {
      let alertCont = UIAlertController.init(
        title: NSLocalizedString("WelcomeScreenAgeVerifyTitle", comment: "An alert title indicating the user needs to verify their age"),
        message: NSLocalizedString("WelcomeScreenAgeVerifyMessage", comment: "An alert message telling the user they must be at least 13 years old and asking how old they are"),
        preferredStyle: .alert
      )
      alertCont.addAction(UIAlertAction.init(title: "Under 13", style: .default, handler: { _ in
        completion(false)
      }))
      alertCont.addAction(UIAlertAction.init(title: "13 or Older", style: .default, handler: { _ in
        completion(true)
      }))
      UIApplication.shared.keyWindow?.rootViewController?.present(alertCont, animated: true, completion: nil)
    }
  }
}
