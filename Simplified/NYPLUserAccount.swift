import Foundation

extension Notification.Name {
  static let NYPLUserAccountDidChange = Notification.Name("NYPLUserAccountDidChangeNotification")
  static let NYPLUserAccountLoginDidChange = Notification.Name("NYPLUserAccountLoginDidChangeNotification")
}

@objc extension NSNotification {
  public static let NYPLUserAccountDidChange = Notification.Name.NYPLUserAccountDidChange
  public static let NYPLUserAccountLoginDidChange = Notification.Name.NYPLUserAccountLoginDidChange
}

private enum StorageKey: String {
  case authorizationIdentifier = "NYPLAccountAuthorization"
  case barcode = "NYPLAccountBarcode" // legacy, replaced with .credentials
  case PIN = "NYPLAccountPIN" // legacy, replaced with .credentials
  case adobeToken = "NYPLAccountAdobeTokenKey"
  case licensor = "NYPLAccountLicensorKey"
  case patron = "NYPLAccountPatronKey"
  case authToken = "NYPLAccountAuthTokenKey" // legacy, replaced with .credentials
  case adobeVendor = "NYPLAccountAdobeVendorKey"
  case provider = "NYPLAccountProviderKey"
  case userID = "NYPLAccountUserIDKey"
  case deviceID = "NYPLAccountDeviceIDKey"
  case credentials = "NYPLAccountCredentialsKey"

  func keyForLibrary(uuid libraryUUID: String?) -> String {
    guard let libraryUUID = libraryUUID else { return self.rawValue }
    return "\(self.rawValue)_\(libraryUUID)"
  }
}

@objcMembers class NYPLUserAccount : NSObject {
  static private let shared = NYPLUserAccount()
  private let accountInfoLock = NSRecursiveLock()
  private lazy var keychainTransaction = KeychainVariableTransaction(accountInfoLock: accountInfoLock)
    
  private var libraryUUID: String?

  public private(set) var credentials: Credentials? {
    get {
      var credentials = _credentials.read()

      if credentials == nil {
        // try to load legacy values
        if let barcode = legacyBarcode, let pin = legacyPin {
          credentials = .barcodeAndPin(barcode: barcode, pin: pin)
        } else if let authToken = legacyAuthToken {
          credentials = .token(authToken: authToken)
        }
      }

      return credentials
    }
    set {
      guard let newValue = newValue else { return }

      _credentials.safeWrite(newValue)

      // make sure to set the barcode related to the current account (aka library)
      // not the one we just signed in to, because we could have signed in into
      // library A, but still browsing the catalog of library B.
      NYPLErrorLogger.setUserID(NYPLUserAccount.sharedAccount().barcode)

      notifyAccountDidChange()
    }
  }

  @objc class func sharedAccount() -> NYPLUserAccount
  {
    return sharedAccount(libraryUUID: AccountsManager.shared.currentAccount?.uuid)
  }
    
  @objc(sharedAccount:)
  class func sharedAccount(libraryUUID: String?) -> NYPLUserAccount
  {
    shared.accountInfoLock.lock()
    defer {
      shared.accountInfoLock.unlock()
    }
    if let uuid = libraryUUID,
      uuid != AccountsManager.NYPLAccountUUIDs[0]
    {
      shared.libraryUUID = uuid
    } else {
      shared.libraryUUID = nil
    }

    return shared
  }

  private func notifyAccountDidChange() {
    NotificationCenter.default.post(
      name: Notification.Name.NYPLUserAccountDidChange,
      object: self
    )
  }

  // MARK: - Storage
  private lazy var _authorizationIdentifier: KeychainVariable<String> = StorageKey.authorizationIdentifier
    .keyForLibrary(uuid: libraryUUID)
    .asKeychainVariable(with: accountInfoLock)
  private lazy var _adobeToken: KeychainVariable<String> = StorageKey.adobeToken
    .keyForLibrary(uuid: libraryUUID)
    .asKeychainVariable(with: accountInfoLock)
  private lazy var _licensor: KeychainVariable<[String:Any]> = StorageKey.licensor
    .keyForLibrary(uuid: libraryUUID)
    .asKeychainVariable(with: accountInfoLock)
  private lazy var _patron: KeychainVariable<[String:Any]> = StorageKey.patron
    .keyForLibrary(uuid: libraryUUID)
    .asKeychainVariable(with: accountInfoLock)
  private lazy var _adobeVendor: KeychainVariable<String> = StorageKey.adobeVendor
    .keyForLibrary(uuid: libraryUUID)
    .asKeychainVariable(with: accountInfoLock)
  private lazy var _provider: KeychainVariable<String> = StorageKey.provider
    .keyForLibrary(uuid: libraryUUID)
    .asKeychainVariable(with: accountInfoLock)
  private lazy var _userID: KeychainVariable<String> = StorageKey.userID
    .keyForLibrary(uuid: libraryUUID)
    .asKeychainVariable(with: accountInfoLock)
  private lazy var _deviceID: KeychainVariable<String> = StorageKey.deviceID
    .keyForLibrary(uuid: libraryUUID)
    .asKeychainVariable(with: accountInfoLock)
  private lazy var _credentials: KeychainVariable<Credentials> = StorageKey.credentials
    .keyForLibrary(uuid: libraryUUID)
    .asKeychainVariable(with: accountInfoLock)

  // Legacy
  private lazy var _barcode: KeychainVariable<String> = StorageKey.barcode
    .keyForLibrary(uuid: libraryUUID)
    .asKeychainVariable(with: accountInfoLock)
  private lazy var _pin: KeychainVariable<String> = StorageKey.PIN
    .keyForLibrary(uuid: libraryUUID)
    .asKeychainVariable(with: accountInfoLock)
  private lazy var _authToken: KeychainVariable<String> = StorageKey.authToken
    .keyForLibrary(uuid: libraryUUID)
    .asKeychainVariable(with: accountInfoLock)

  // MARK: - Check
    
  func hasBarcodeAndPIN() -> Bool {
    if let credentials = credentials, case Credentials.barcodeAndPin = credentials {
      return true
    } else {
      return false
    }
  }
  
  func hasAuthToken() -> Bool {
    if let credentials = credentials, case Credentials.token = credentials {
      return true
    } else {
      return false
    }
  }
  
  func hasAdobeToken() -> Bool {
    return adobeToken != nil
  }
  
  func hasLicensor() -> Bool {
    return licensor != nil
  }
  
  func hasCredentials() -> Bool {
    return credentials != nil
  }

  // MARK: - Legacy
  private var legacyBarcode: String? { return _barcode.read() }
  private var legacyPin: String? { return _pin.read() }
  var legacyAuthToken: String? { _authToken.read() }

  // MARK: - GET
  var authorizationIdentifier: String? { _authorizationIdentifier.read() }
  var deviceID: String? { _deviceID.read() }
  var userID: String? { _userID.read() }
  var adobeVendor: String? { _adobeVendor.read() }
  var provider: String? { _provider.read() }
  var patron: [String:Any]? { _patron.read() }
  var adobeToken: String? { _adobeToken.read() }
  var licensor: [String:Any]? { _licensor.read() }

  var barcode: String? {
    if let credentials = credentials, case let Credentials.barcodeAndPin(barcode: barcode, pin: _) = credentials {
      return barcode
    } else {
      return nil
    }
  }

  var PIN: String? {
    if let credentials = credentials, case let Credentials.barcodeAndPin(barcode: _, pin: pin) = credentials {
      return pin
    } else {
      return nil
    }
  }

  var authToken: String? {
    if let credentials = credentials, case let Credentials.token(authToken: token) = credentials {
      return token
    } else {
      return nil
    }
  }


  var patronFullName: String? {
    if let patron = patron,
      let name = patron["name"] as? [String:String]
    {
      var fullname = ""
      
      if let first = name["first"] {
        fullname.append(first)
      }
      
      if let middle = name["middle"] {
        if fullname.count > 0 {
          fullname.append(" ")
        }
        fullname.append(middle)
      }
      
      if let last = name["last"] {
        if fullname.count > 0 {
          fullname.append(" ")
        }
        fullname.append(last)
      }
      
      return fullname.count > 0 ? fullname : nil
    }
    
    return nil
  }



  // MARK: - SET
  @objc(setBarcode:PIN:)
  func setBarcode(_ barcode: String, PIN: String) {
    credentials = .barcodeAndPin(barcode: barcode, pin: PIN)
  }
    
  @objc(setAdobeToken:patron:)
  func setAdobeToken(_ token: String, patron: [String : Any]) {
    keychainTransaction.write {
      _adobeToken.write(token)
      _patron.write(patron)
    }

    notifyAccountDidChange()
  }
  
  @objc(setAdobeVendor:)
  func setAdobeVendor(_ vendor: String) {
    _adobeVendor.safeWrite(vendor)
    notifyAccountDidChange()
  }
  
  @objc(setAdobeToken:)
  func setAdobeToken(_ token: String) {
    _adobeToken.safeWrite(token)
    notifyAccountDidChange()
  }
  
  @objc(setLicensor:)
  func setLicensor(_ licensor: [String : Any]) {
    _licensor.safeWrite(licensor)
  }
  
  @objc(setAuthorizationIdentifier:)
  func setAuthorizationIdentifier(_ identifier: String) {
    _authorizationIdentifier.safeWrite(identifier)
  }
  
  @objc(setPatron:)
  func setPatron(_ patron: [String : Any]) {
    _patron.safeWrite(patron)
    notifyAccountDidChange()
  }
  
  @objc(setAuthToken:)
  func setAuthToken(_ token: String) {
    credentials = .token(authToken: token)
  }
  
  @objc(setProvider:)
  func setProvider(_ provider: String) {
    _provider.safeWrite(provider)
    notifyAccountDidChange()
  }
  
  @objc(setUserID:)
  func setUserID(_ id: String) {
    _userID.safeWrite(id)
    notifyAccountDidChange()
  }
  
  @objc(setDeviceID:)
  func setDeviceID(_ id: String) {
    _deviceID.safeWrite(id)
    notifyAccountDidChange()
  }
    
  // MARK: - Remove
  func removeAll() {
    keychainTransaction.write {
      _credentials.write(nil)
      _authorizationIdentifier.write(nil)
      _adobeToken.write(nil)
      _patron.write(nil)
      _authToken.write(nil)
      _adobeVendor.write(nil)
      _provider.write(nil)
      _userID.write(nil)
      _deviceID.write(nil)
    }
    notifyAccountDidChange()
  }
}
