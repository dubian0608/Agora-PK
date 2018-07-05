//
//  RoomViewController.swift
//  AgoraPK
//
//  Created by ZhangJi on 2018/7/4.
//  Copyright © 2018年 ZhangJi. All rights reserved.
//

import UIKit
import AgoraRtcEngineKit

let pkViewWidth = ScreenWidth / 2.0
let pkViewHeight = ScreenWidth / 9.0 * 8

class RoomViewController: UIViewController {

    @IBOutlet weak var hostContainView: UIView!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var pkButton: UIButton!
    @IBOutlet weak var accountLabel: UILabel!
    
    var agoraKit: AgoraRtcEngineKit!
    var clientRole = AgoraClientRole.audience
    
    var mediaRoomName: String!
    
    fileprivate var isBroadcaster: Bool {
        return clientRole == .broadcaster
    }
    var videoSessions = [VideoSession]() {
        didSet {
            updateHostView()
        }
    }
    
    var pkRoomeName: String?
    
    var isHost = true
    
    var isPk = false {
        didSet {
            if !isInRoom || self.isPk != oldValue {
                DispatchQueue.main.async {
                    self.updateViewWithStatus(isPk: self.isPk)
                }
            }
        }
    }
    
    var pkAccount: String?
    
    var isInRoom = false
    
    var signalRoomName: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.muteButton.isHidden = !isBroadcaster
        self.switchCameraButton.isHidden = !isBroadcaster
        self.pkButton.isHidden = !isBroadcaster
        self.accountLabel.text = "Account: " + (UserDefaults.standard.object(forKey: "myAccount") as! String)
        
        loadAgoraSignal()
        
        if isBroadcaster {
            loadAgoraKit(withIsPk: isPk)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateHostView() {
        
        switch videoSessions.count {
        case 1:
            videoSessions[0].hostingView.frame = self.hostContainView.frame
        case 2:
            videoSessions[0].hostingView.frame = CGRect(x: 0, y: ScreenHeight / 7, width: pkViewWidth, height: pkViewHeight)
            videoSessions[1].hostingView.frame = CGRect(x: pkViewWidth, y: ScreenHeight / 7, width: pkViewWidth, height: pkViewHeight)
        default:
            return
        }
    }
    
    func updateViewWithStatus(isPk: Bool) {
        if isBroadcaster {
            self.pkButton.isSelected = self.isPk
            leaveChannel()
            loadAgoraKit(withIsPk: isPk)
            
            var messageJson = Dictionary<String, Any>()
            messageJson["type"] = "pkStatus"
            messageJson["status"] = self.isPk
            messageJson["roomName"] = self.isPk ? self.pkRoomeName : self.mediaRoomName
            
            guard let msg = self.getJsonStringWith(dic: messageJson) else {
                return
            }
            AgoraSignal.Kit.messageChannelSend(self.signalRoomName, msg: msg, msgID: "")
        } else {
            if isInRoom {
                leaveChannel()
            }
            loadAgoraKit(withIsPk: isPk)
        }
    }
    
    @IBAction func doMutePressed(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        agoraKit.muteLocalAudioStream(sender.isSelected)
    }
    
    @IBAction func doSwitchCameraPressed(_ sender: UIButton) {
        agoraKit.switchCamera()
    }
    
    @IBAction func doPkPressed(_ sender: UIButton) {
        if sender.isSelected {
            var messageJson = Dictionary<String, Any>()
            messageJson["type"] = "pkRequest"
            messageJson["status"] = false
            
            guard let msg = self.getJsonStringWith(dic: messageJson) else {
                return
            }
            AgoraSignal.Kit.messageInstantSend(pkAccount!, uid: 0, msg: msg, msgID: "")
            
            sender.isSelected = false
            
            if !isHost {
                self.isPk = false
            }
        } else {
            let popView = PopView.newPopViewWith(buttonTitle: "Request PK", placeholder: "Please enter user name")
            popView?.frame = CGRect(x: 0, y: ScreenHeight, width: ScreenWidth, height: ScreenHeight)
            popView?.delegate = self
            self.view.addSubview(popView!)
            UIView.animate(withDuration: 0.2) {
                popView?.frame = self.view.frame
            }
        }
    }
    
    @IBAction func doLeavePressed(_ sender: UIButton) {
        leaveChannel()
        setIdleTimerActive(false)
        navigationController?.popViewController(animated: true)
        
    }
    
    func setIdleTimerActive(_ active: Bool) {
        UIApplication.shared.isIdleTimerDisabled = !active
    }
}

// MARK: - Agora Media
private extension RoomViewController {
    func loadAgoraKit(withIsPk status: Bool) {
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: KeyCenter.AppId, delegate: self)
        agoraKit.setChannelProfile(.liveBroadcasting)
        agoraKit.setClientRole(self.clientRole)
        agoraKit.enableVideo()
        agoraKit.setVideoProfile(.portrait360P, swapWidthAndHeight: false)
        
        if isBroadcaster {
            agoraKit.startPreview()
            self.addLocalSession()
            let session = videoSession(ofUid: 0)
            UIView.animate(withDuration: 0.2) {
                session.hostingView.frame = status ? CGRect(x: 0, y: ScreenHeight / 7, width: pkViewWidth, height: pkViewHeight) : self.hostContainView.frame
            }
        }
        
        let code = agoraKit.joinChannel(byToken: nil, channelId: status ? self.pkRoomeName! : self.mediaRoomName, info: nil, uid: 0, joinSuccess: nil)
        if code == 0 {
            setIdleTimerActive(false)
            agoraKit.setEnableSpeakerphone(true)
        }
        
    }
    
    func addLocalSession() {
        let session = VideoSession.localSession()
        agoraKit.setupLocalVideo(session.canvas)
        self.hostContainView.addSubview((session.hostingView)!)
        
        videoSessions.append(session)
    }
    
    func fetchSession(ofUid uid: UInt) -> VideoSession? {
        for session in videoSessions {
            if session.uid == uid {
                return session
            }
        }
        return nil
    }
    
    func videoSession(ofUid uid: UInt) -> VideoSession {
        if let fetchedSession = fetchSession(ofUid: uid) {
            return fetchedSession
        } else {
            let newSession = VideoSession(uid: uid)
            self.hostContainView.addSubview((newSession.hostingView)!)
            
            videoSessions.append(newSession)
            return newSession
        }
    }
    
    func leaveChannel() {
        for session in videoSessions {
            session.hostingView.removeFromSuperview()
        }
        videoSessions.removeAll()
        agoraKit.leaveChannel(nil)
        isInRoom = false
    }
}

// MARK: - AgoraRtcEngineDelegate
extension RoomViewController: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        isInRoom = true
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        if videoSessions.count < 2 {
            let session = videoSession(ofUid: uid)
            agoraKit.setupRemoteVideo(session.canvas)
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        var indexToDelete: Int?
        for (index, session) in videoSessions.enumerated() {
            if session.uid == Int64(uid) {
                indexToDelete = index
            }
        }
        
        if let indexToDelete = indexToDelete {
            let deletedSession = videoSessions.remove(at: indexToDelete)
            deletedSession.hostingView.removeFromSuperview()
        }
    }
}

// MARK: - Pop View Delegate
extension RoomViewController: PopViewDelegate {
    func popViewButtonDidPressed(_ popView: PopView) {
        guard let account = popView.inputTextField.text else {
            return
        }
        if !check(String: account) {
            return
        }
        var messageJson = Dictionary<String, Any>()
        messageJson["type"] = "pkRequest"
        messageJson["status"] = !self.isPk

        guard let msg = self.getJsonStringWith(dic: messageJson) else {
            return
        }
        AgoraSignal.Kit.messageInstantSend(account, uid: 0, msg: msg, msgID: "")

        popView.removeFromSuperview()
    }
    
    func popViewDidRemoved(_ popView: PopView) {
//        popViewIsShow = false
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


// MARK: - Agora Singal

private extension RoomViewController {
    func loadAgoraSignal() {
        addAgoraSignalBlock()
        
        AgoraSignal.Kit.channelJoin(self.signalRoomName)
    }
    
    func getJsonStringWith(dic: Dictionary<String, Any>) -> String? {
        do {
            let data = try JSONSerialization.data(withJSONObject: dic, options: .prettyPrinted)
            let stringData = String.init(data: data, encoding: String.Encoding.utf8)
            return stringData
        } catch {
            return nil
        }
    }
    
    func addAgoraSignalBlock() {
        AgoraSignal.Kit.onChannelJoined = { [weak self] (channelID) -> () in
            guard let isBroadcater = self?.isBroadcaster  else {
                return
            }
            if isBroadcater {
                var messageJson = Dictionary<String, Any>()
                messageJson["type"] = "pkStatus"
                messageJson["status"] = (self?.isPk)!
                messageJson["roomName"] = (self?.isPk)! ? (self?.pkRoomeName)! : (self?.mediaRoomName)!
                
                guard let msg = self?.getJsonStringWith(dic: messageJson) else {
                    return
                }
                AgoraSignal.Kit.messageChannelSend((self?.signalRoomName)!, msg: msg, msgID: "")
            }
        }
        
        AgoraSignal.Kit.onLogout = { [weak self] (ecode) -> () in
            guard let isInRoom = self?.isInRoom else {
                return
            }
            if isInRoom {
                self?.leaveChannel()
            }
            DispatchQueue.main.async(execute: {
                self?.dismiss(animated: true, completion: nil)
            })
        }
        
        AgoraSignal.Kit.onMessageChannelReceive = { [weak self] (channelID, account, uid, msg) -> () in
            guard let isBroadcater = self?.isBroadcaster  else {
                return
            }
            if !isBroadcater {
                let data = msg?.data(using: String.Encoding.utf8)
                do {
                    let msgDic: NSDictionary = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as! NSDictionary
                    guard let type = msgDic["type"] as? String else {
                        return
                    }
                    switch type {
                    case "pkStatus":
                        guard let pkStatus =  msgDic["status"] as? Bool else {
                            return
                        }
                        guard let roomName = msgDic["roomName"] as? String else {
                            return
                        }
                        if pkStatus {
                            self?.pkRoomeName = roomName
                        } else {
                            self?.mediaRoomName = roomName
                        }
                        
                        self?.isPk = pkStatus
                        
                    default:
                        return
                    }
                } catch  {
                    AlertUtil.showAlert(message: "Receive message error: \(error)")
                    print("Error: \(error)")
                }
            }
        }
        
        AgoraSignal.Kit.onChannelUserJoined = { [weak self] (account, uid) -> () in
            guard let isBroadcater = self?.isBroadcaster  else {
                return
            }
            if isBroadcater {
                var messageJson = Dictionary<String, Any>()
                messageJson["type"] = "pkStatus"
                messageJson["status"] = (self?.isPk)!
                messageJson["roomName"] = (self?.isPk)! ? (self?.pkRoomeName)! : (self?.mediaRoomName)!
                guard let msg = self?.getJsonStringWith(dic: messageJson) else {
                    return
                }
                AgoraSignal.Kit.messageInstantSend(account, uid: 0, msg: msg, msgID: "")
            }
        }

        AgoraSignal.Kit.onMessageInstantReceive = { [weak self] (account, uid, msg) -> () in
            let data = msg?.data(using: String.Encoding.utf8)
            do {
                let msgDic: NSDictionary = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as! NSDictionary
                guard let type = msgDic["type"] as? String else {
                    return
                }
                switch type {
                case "pkStatus":
                    guard let pkStatus =  msgDic["status"] as? Bool else {
                        return
                    }
                    guard let roomName = msgDic["roomName"] as? String else {
                        return
                    }
                    
                    if pkStatus {
                        self?.pkRoomeName = roomName
                    } else {
                        self?.mediaRoomName = roomName
                    }
                    self?.isPk = pkStatus

                case "pkRequest":
                    guard let status =  msgDic["status"] as? Bool else {
                        return
                    }
                    if status {
                        let pkRequestView = UIAlertController(title: "\(account!) request PK with you", message: nil, preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "OK", style: .default, handler: { (_) in
                            var messageJson = Dictionary<String, Any>()
                            messageJson["type"] = "pkAccept"
                            messageJson["status"] = true
                            
                            guard let msg = self?.getJsonStringWith(dic: messageJson) else {
                                return
                            }
                            AgoraSignal.Kit.messageInstantSend(account, uid: 0, msg: msg, msgID: "")
                            self?.pkButton.isSelected = true
                            self?.pkAccount = account!
                        })
                        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                            var messageJson = Dictionary<String, Any>()
                            messageJson["type"] = "pkAccept"
                            messageJson["status"] = false
                            
                            guard let msg = self?.getJsonStringWith(dic: messageJson) else {
                                return
                            }
                            AgoraSignal.Kit.messageInstantSend(account, uid: 0, msg: msg, msgID: "")
                        })
                        
                        pkRequestView.addAction(okAction)
                        pkRequestView.addAction(cancelAction)
                        
                        self?.present(pkRequestView, animated: true, completion: nil)
                    } else {
                        if (self?.isHost)! {
                            self?.pkButton.isSelected = false
                            AlertUtil.showAlert(message: "\(account!) leave PK room")
                        } else {
                            AlertUtil.showAlert(message: "\(account!) request you leave PK room")
                            self?.isPk = false
                            self?.isHost = true
                            self?.pkRoomeName = nil
                            self?.pkAccount = nil
                        }
                    }
                    
                case "pkAccept":
                    guard let res = msgDic["status"] as? Bool else {
                        return
                    }
                    AlertUtil.showAlert(message: "\(account!) \(res ? "accepted" : "refused") your request")
                    
                    if res {
                        self?.isHost = false
                        self?.isPk = res
                        self?.pkRoomeName = account!
                        self?.pkAccount = account!
                    }
                    
                default:
                    return
                }
            } catch  {
                AlertUtil.showAlert(message: "Receive message error: \(error)")
                print("Error: \(error)")
            }
        }
    }
}
