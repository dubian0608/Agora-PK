//
//  MainViewController.swift
//  AgoraPK
//
//  Created by ZhangJi on 2018/7/4.
//  Copyright © 2018年 ZhangJi. All rights reserved.
//

import UIKit
import AgoraRtcEngineKit

class MainViewController: UIViewController {
    
    var subscribeAccount: String?
    var role: AgoraClientRole!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        addAgoraSignalBlock()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let roomVC = segue.destination as! RoomViewController
        if let value = sender as? NSNumber, let role = AgoraClientRole(rawValue: value.intValue) {
            roomVC.clientRole = role
            switch role {
            case .audience: roomVC.signalRoomName = subscribeAccount
            case .broadcaster:
                roomVC.signalRoomName = UserDefaults.standard.object(forKey: "myAccount") as? String
                roomVC.mediaRoomName = UserDefaults.standard.object(forKey: "myAccount") as! String
            }
        }
    }
    
    @IBAction func doBackButtonPressed(_ sender: UIButton) {
        AgoraSignal.Kit.logout()
    }
    
    @IBAction func doPublishButtonPressed(_ sender: UIButton) {
        self.joinRoom(withRole: .broadcaster)
    }
    
    @IBAction func doSubscribeButtonPressed(_ sender: UIButton) {
        let popView = PopView.newPopViewWith(buttonTitle: "Watch broadcasting", placeholder: "Please enter user name")
        popView?.frame = CGRect(x: 0, y: ScreenHeight, width: ScreenWidth, height: ScreenHeight)
        popView?.delegate = self
        self.view.addSubview(popView!)
        UIView.animate(withDuration: 0.2) {
            popView?.frame = self.view.frame
        }
    }
}

private extension MainViewController {
    func joinRoom(withRole role: AgoraClientRole) {
        self.performSegue(withIdentifier: "toRoom", sender: NSNumber(value: role.rawValue as Int))
    }
    
    func addAgoraSignalBlock() {
        AgoraSignal.Kit.onLogout = { [weak self] (ecode) -> () in
            DispatchQueue.main.async(execute: {
                self?.dismiss(animated: true, completion: nil)
            })
        }
    }
}

extension MainViewController: PopViewDelegate {
    func popViewButtonDidPressed(_ popView: PopView) {
        guard let account = popView.inputTextField.text else {
            return
        }
        if !check(String: account) {
            return
        }
        self.subscribeAccount = account
        
        self.joinRoom(withRole: .audience)
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
