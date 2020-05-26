//
//  NYPLAccountSignInViewControllerSwift.swift
//  SimplyE
//
//  Created by Jacek Szyja on 26/05/2020.
//  Copyright © 2020 NYPL Labs. All rights reserved.
//

import CoreLocation
import LocalAuthentication
import MessageUI
import NYPLCardCreator
import PureLayout
import UIKit

private enum CellType
{
  case authenticationMethod(name: String) // cell with radio button and name of the identity provider

  case barcodeImage
  case barcode(fieldName: String, value: String?)
  case pin(fieldName: String, value: String?)

  case logIn
  case logOut

  case advancedSettings
  case ageCheck

  case registration
  case syncButton

  case privacyPolicy
  case contentLicense
  case reportIssue
}

class NYPLAccountSignInViewControllerSwift: UITableViewController, NYPLUserAccountInputProvider {
  var businessLogic: NYPLSignInBusinessLogic!
  var frontEndValidator: NYPLUserAccountFrontEndValidation!

  private var _libraryUUID: String?
  private var libraryID: String {
    get {
      let libraryID = _libraryUUID ?? AccountsManager.shared.currentAccountId
      assert(libraryID != nil, "Tried to initialize NYPLSettingsAccountDetailViewController with the current library ID but that appears to be nil. A release build will continue with an empty library ID but this will likely produce unexpected behavior.");
      return libraryID ?? ""
    }
    set {
      _libraryUUID = newValue
    }
  }


  // MARK: UI
  var logInSignOutCell: UITableViewCell!
  var pinShowHideButton: UIButton!

  // NYPLUserAccountInputProvider
  var usernameTextField: UITextField!
  var pinTextField: UITextField!

  init(style: UITableView.Style, libraryUUID: String) {
    super.init(style: style)
    let logic = NYPLSignInBusinessLogic(libraryAccountID: libraryUUID)
    businessLogic = logic
    frontEndValidator = NYPLUserAccountFrontEndValidation(account: logic.libraryAccount,
                                                          inputProvider: self)
    title = NSLocalizedString("Account", comment: "Account title")

    NotificationCenter.default.addObserver(self,
                                           selector: #selector(keyboardDidShow(notification:)),
                                           name: UIResponder.keyboardWillShowNotification,
                                           object: nil)

    NotificationCenter.default.addObserver(self,
                                           selector: #selector(willResignActive),
                                           name: UIApplication.willResignActiveNotification,
                                           object: nil)

    NotificationCenter.default.addObserver(self,
                                           selector: #selector(willEnterForeground),
                                           name: UIApplication.willEnterForegroundNotification,
                                           object: nil)
  }

  convenience init(libraryUUID: String) {
    self.init(style: .grouped, libraryUUID: libraryUUID)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}


// MARK: - Barcode and pin UI logic
extension NYPLAccountSignInViewControllerSwift {
  private func togglePINShowHideState() {
    pinTextField.isSecureTextEntry = !pinTextField.isSecureTextEntry
    let title = pinTextField.isSecureTextEntry ? "Show" : "Hide"
    let localizedTitle = NSLocalizedString(title, comment: "")
    pinShowHideButton.setTitle(localizedTitle, for: .normal)
    pinShowHideButton.sizeToFit()
    tableView.reloadData()
  }

  private func updateShowHidePINState() {
    let canEvaluate = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication,
                                                    error: nil)
    pinTextField.rightView?.isHidden = !canEvaluate
  }
}

















// MARK: - System notification observers
extension NYPLAccountSignInViewControllerSwift {
  @objc
  private func keyboardDidShow(notification: Notification) {
    DispatchQueue.main.async {
      let isHorizontalCompact = self.traitCollection.horizontalSizeClass == .compact
      let isVerticalCompact = self.traitCollection.verticalSizeClass == .compact
      let isCompactUI = isHorizontalCompact && isVerticalCompact
      let isIphone = UIDevice.current.userInterfaceIdiom == .phone

      guard isIphone || isCompactUI else { return }

      guard let info = notification.userInfo else { return }
      guard let keyboardSize = (info[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect)?.size else { return }

      var visibleRect = self.view.frame
      visibleRect.size.height -= keyboardSize.height + self.tableView.contentInset.top

      guard !visibleRect.contains(CGPoint(x: 0, y: self.logInSignOutCell.frame.maxY)) else { return }

      UIView.animate(withDuration: 0.25) {
        self.tableView.setContentOffset(CGPoint(x: 0,
                                                y: -self.tableView.contentInset.top + 20),
                                        animated: true)
      }
    }
  }

  @objc private func willResignActive() {
    guard !pinTextField.isSecureTextEntry else { return }
    togglePINShowHideState()
  }

  @objc private func willEnterForeground() {
    DispatchQueue.main.async {
      self.updateShowHidePINState()
    }
  }
}
