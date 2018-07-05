//
//  LoginViewController.swift
//  AgoraPK
//
//  Created by ZhangJi on 2018/7/4.
//  Copyright © 2018年 ZhangJi. All rights reserved.
//

import UIKit
import AgoraSigKit

class LoginViewController: UIViewController {

    @IBOutlet weak var accountTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addKeyboardObserver()
        addAgoraSignalBlock()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    @IBAction func doLoginButtonPressed(_ sender: UIButton) {
        guard let account = accountTextField.text else {
            return
        }
        if !check(String: account) {
            return
        }
        UserDefaults.standard.set(account, forKey: "myAccount")
        
        AgoraSignal.Kit.login2(KeyCenter.AppId, account: account, token: "_no_need_token", uid: 0, deviceID: nil, retry_time_in_s: 60, retry_count: 5)
    }
    
    func check(String: String) -> Bool {
        if String.isEmpty {
            AlertUtil.showAlert(message: "The account is empty !")
            return false
        }
        if String.count > 128 {
            AlertUtil.showAlert(message: "The accout is longer than 128 !")
            return false
        }
        if String.contains(" ") {
            AlertUtil.showAlert(message: "The accout contains space !")
            return false
        }
        return true
    }
}

private extension LoginViewController {
    func addAgoraSignalBlock() {
        AgoraSignal.Kit.onLoginSuccess = { [weak self] (uid,fd) -> () in
            DispatchQueue.main.async(execute: {
                self?.performSegue(withIdentifier: "toMain", sender: self)
            })
        }
        
        AgoraSignal.Kit.onLoginFailed = { (ecode) -> () in
            AlertUtil.showAlert(message: "Login failed with error: \(ecode.rawValue)")
        }
        
        AgoraSignal.Kit.onLog = { (txt) -> () in
            guard var log = txt else {
                return
            }
            let time = log[..<log.index(log.startIndex, offsetBy: 10)]
            let dformatter = DateFormatter()
            let timeInterval = TimeInterval(Int(time)!)
            let date = Date(timeIntervalSince1970: timeInterval)
            dformatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            log.replaceSubrange(log.startIndex..<log.index(log.startIndex, offsetBy: 10), with: dformatter.string(from: date) + ".")
            
            LogWriter.write(log: log)
        }
    }
}

private extension LoginViewController {
    func addKeyboardObserver() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardWillShow, object: nil, queue: nil) { [weak self] notify in
            guard let strongSelf = self, let userInfo = (notify as NSNotification).userInfo,
                let keyBoardBoundsValue = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue,
                let durationValue = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber else {
                    return
            }
            
            let keyBoardBounds = keyBoardBoundsValue.cgRectValue
            let duration = durationValue.doubleValue
            var deltaY = isIPhoneX ? keyBoardBounds.size.height + 34 : keyBoardBounds.size.height
            deltaY -= ScreenHeight - (self?.loginButton.frame.maxY)! - 10
            
            if duration > 0 {
                var optionsInt: UInt = 0
                if let optionsValue = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber {
                    optionsInt = optionsValue.uintValue
                }
                let options = UIViewAnimationOptions(rawValue: optionsInt)
                
                UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
                    strongSelf.view.frame = CGRect(x: 0, y: -deltaY, width: ScreenWidth, height: ScreenHeight)
                    strongSelf.view?.layoutIfNeeded()
                }, completion: nil)
                
            } else {
                strongSelf.view.frame = CGRect(x: 0, y: -deltaY, width: ScreenWidth, height: ScreenHeight)
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardWillHide, object: nil, queue: nil) { [weak self] notify in
            guard let strongSelf = self else {
                return
            }
            
            let duration: Double
            if let userInfo = (notify as NSNotification).userInfo, let durationValue = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber {
                duration = durationValue.doubleValue
            } else {
                duration = 0
            }
            
            if duration > 0 {
                var optionsInt: UInt = 0
                if let userInfo = (notify as NSNotification).userInfo, let optionsValue = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber {
                    optionsInt = optionsValue.uintValue
                }
                let options = UIViewAnimationOptions(rawValue: optionsInt)
                
                UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
                    strongSelf.view.frame = CGRect(x: 0, y: 0, width: ScreenWidth, height: ScreenHeight)
                    strongSelf.view?.layoutIfNeeded()
                }, completion: nil)
                
            } else {
                strongSelf.view.frame = CGRect(x: 0, y: 0, width: ScreenWidth, height: ScreenHeight)
            }
        }
    }
}

