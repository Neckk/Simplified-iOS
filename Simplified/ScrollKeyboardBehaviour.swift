//
//  ScrollKeyboardBehaviour.swift
//  SimplyE
//
//  Created by Jacek Szyja on 26/05/2020.
//  Copyright © 2020 NYPL Labs. All rights reserved.
//

import UIKit

@available(iOS 11.0, *)
public class ScrollKeyboardBehaviour: NSObject {
  @IBOutlet private weak var scrollView: UIScrollView?
  @IBOutlet private weak var viewController: UIViewController? {
    didSet {
      NotificationCenter
        .default
        .addObserver(self,
                     selector: #selector(ScrollKeyboardBehaviour.keyboardWillShow),
                     name: UIResponder.keyboardWillShowNotification,
                     object: nil)
      NotificationCenter
        .default
        .addObserver(self,
                     selector: #selector(ScrollKeyboardBehaviour.keyboardWillChangeFrame),
                     name: UIResponder.keyboardWillChangeFrameNotification,
                     object: nil)
      NotificationCenter
        .default
        .addObserver(self,
                     selector: #selector(ScrollKeyboardBehaviour.keyboardWillHide),
                     name: UIResponder.keyboardWillHideNotification,
                     object: nil)
    }
  }

  //MARK: Methods to manage keybaord
  @objc private func keyboardWillShow(notification: NSNotification) {
    let info = notification.userInfo
    let keyBoardSize = info![UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
    let insetValue = keyBoardSize.height - (scrollView?.safeAreaInsets.bottom ?? 0)
    let inset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: insetValue, right: 0.0)
    scrollView?.contentInset = inset
    scrollView?.scrollIndicatorInsets = inset
  }

  @objc private func keyboardWillChangeFrame(notification: NSNotification) {
    let info = notification.userInfo
    let keyBoardSize = info![UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
    let insetValue = keyBoardSize.height - (scrollView?.safeAreaInsets.bottom ?? 0)
    let inset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: insetValue, right: 0.0)
    scrollView?.contentInset = inset
    scrollView?.scrollIndicatorInsets = inset
  }

  @objc private func keyboardWillHide(notification: NSNotification) {
    scrollView?.contentInset = UIEdgeInsets.zero
    scrollView?.scrollIndicatorInsets = UIEdgeInsets.zero
  }
}

