//
//  ViewController.swift
//  Spotify-Demo
//  Copyright © 2019 All rights reserved.

import UIKit
import WebKit
import CoreMotion
@_exported import AVFoundation

class ViewController: UIViewController, SPTAudioStreamingPlaybackDelegate, SPTAudioStreamingDelegate {
    var auth = SPTAuth.defaultInstance()!
    var session:SPTSession!
    var player: SPTAudioStreamingController?
    var loginUrl: URL?
    var myplaylists = [SPTPartialPlaylist]()
    
    
    @IBOutlet var spotifyButton: UIButton!
    @IBOutlet var searchButtn: UIButton!
    
    @IBOutlet weak var rect1: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        if let name = UserDefaults.standard.string(forKey: "Access Token"){
            let date = Date()
            let expiryTime = UserDefaults.standard.object(forKey: "Token Expiration") as! Date
            if(date > expiryTime){
                print("Token already acquired: ", name)
                print("Skip this step")
                let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                let newViewController = storyBoard.instantiateViewController(withIdentifier: "StartRunPage") as! StartRunPage
                self.navigationController?.pushViewController(newViewController, animated: true)
                
            }
            else {
                print("Token expired: ", name)
                print("Login Required")
                UserDefaults.standard.removeObject(forKey: "Access Token")
                UserDefaults.standard.removeObject(forKey:  "Token Expiration")
            }
        }
        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.updateAfterFirstLogin), name: NSNotification.Name(rawValue: "loginSuccessfull"), object: nil)
    }
    func setup () {
        // insert redirect your url and client ID below
        let redirectURL = "Spotify-Demo://returnAfterLogin" // put your redirect URL here
        auth.redirectURL     = URL(string: redirectURL)
        auth.clientID        = "ac34d0bddec746f7b9150b3986297276"
        auth.requestedScopes = [SPTAuthStreamingScope, SPTAuthPlaylistReadPrivateScope, SPTAuthPlaylistModifyPublicScope, SPTAuthPlaylistModifyPrivateScope]
        loginUrl = auth.spotifyWebAuthenticationURL()
        
        searchButtn.alpha = 0
    }
    func initializaPlayer(authSession:SPTSession){
        if self.player == nil {
            self.player = SPTAudioStreamingController.sharedInstance()
            self.player!.playbackDelegate = self
            self.player!.delegate = self
            try! player?.start(withClientId: auth.clientID)
            self.player!.login(withAccessToken: authSession.accessToken)
        }
    }
    
    @objc func updateAfterFirstLogin () {
        
        spotifyButton.isHidden = true
        searchButtn.alpha = 1
        let userDefaults = UserDefaults.standard
        
        if let sessionObj:AnyObject = userDefaults.object(forKey: "SpotifySession") as AnyObject? {
            
            let sessionDataObj = sessionObj as! Data
            let firstTimeSession = NSKeyedUnarchiver.unarchiveObject(with: sessionDataObj) as! SPTSession
            
            self.session = firstTimeSession
            //   initializaPlayer(authSession: session)
            self.spotifyButton.isHidden = true
            AuthService.instance.sessiontokenId = session.accessToken!
            UserDefaults.standard.set(session.accessToken!, forKey: "Access Token")
            let now = Date()
            let date = now.addingTimeInterval(59.0 * 60.0)
            UserDefaults.standard.set(date, forKey:  "Token Expiration")
            print(AuthService.instance.sessiontokenId!)
            SPTUser.requestCurrentUser(withAccessToken: session.accessToken) { (error, data) in
                guard let user = data as? SPTUser else { print("Couldn't cast as SPTUser"); return }
                AuthService.instance.sessionuserId = user.canonicalUserName
                
                print(AuthService.instance.sessionuserId!)
                
                
            }
            // Method 1 : To get current user's playlist
            SPTPlaylistList.playlists(forUser: session.canonicalUsername, withAccessToken: session.accessToken, callback: { (error, response) in
                if let listPage = response as? SPTPlaylistList, let playlists = listPage.items as? [SPTPartialPlaylist] {
                    print(playlists)   // or however you want to parse these
                    //  self.myplaylists = playlists
                    self.myplaylists.append(contentsOf: playlists)
                    print(self.myplaylists)
                }
            })
            // Method 2 : To get current user's playlist
            let playListRequest = try! SPTPlaylistList.createRequestForGettingPlaylists(forUser: AuthService.instance.sessionuserId ?? "", withAccessToken: AuthService.instance.sessiontokenId ?? "")
            Alamofire.request(playListRequest)
                .response { response in
                    
                    
                    let list = try! SPTPlaylistList(from: response.data, with: response.response)
                    for playList in list.items ?? []{
                        if let playlist = playList as? SPTPartialPlaylist {
                            print( playlist.name! ) // playlist name
                            print( playlist.uri!)    // playlist uri
                        }}
            }
            
        }
        
    }
    
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        // after a user authenticates a session, the SPTAudioStreamingController is then initialized and this method called
        print("logged in")
        SPTUser.requestCurrentUser(withAccessToken: session.accessToken) { (error, data) in
            guard let user = data as? SPTUser else { print("Couldn't cast as SPTUser"); return }
            AuthService.instance.sessionuserId = user.canonicalUserName
            print(AuthService.instance.sessionuserId!)
        }
        
        //                self.player?.playSpotifyURI("spotify:track:60a0Rd6pjrkxjPbaKzXjfq", startingWith: 1, startingWithPosition: 8, callback: { (error) in
        //                    if (error != nil) {
        //                        print("playing!")
        //                    }
        //                })
        
    }
    
    
    @IBAction func tableViewTapped(_ sender: Any) {
        UIApplication.shared.open(loginUrl!, options: [:], completionHandler: nil)
        
        /*      if UIApplication.shared.openURL(loginUrl!) {
         if auth.canHandle(auth.redirectURL) {
         // To do - build in error handling
         }
         } */
        
    }
    
    @IBAction func searchSpotifyBTapped(_ sender: Any) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let newViewController = storyBoard.instantiateViewController(withIdentifier: "StartRunPage") as! StartRunPage
        self.navigationController?.pushViewController(newViewController, animated: true)
    }
    
}

extension UIViewController {
    
    func showToast(message : String) {
        
        let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - 140 , y: self.view.frame.size.height - 100, width: 280, height: 50))
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center;
        toastLabel.font = UIFont(name: "Montserrat-Light", size: 12.0)
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        self.view.addSubview(toastLabel)
        UIView.animate(withDuration: 10.0, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
    } }

public class Pedometer{
    var motion = CMMotionManager()
    var pedometer = CMPedometer()
    
    init(){
        startAccelerometer()
        startMotionCapture()
        if (CMPedometer.isStepCountingAvailable()) {
            calculateSteps()
        }
    }
    
    
    private func updateSteps(startDate: Date) {
        pedometer.queryPedometerData(from: startDate, to: Date()) {
            pedometerData, error in
            if let pedometerData = pedometerData {
                print(pedometerData.averageActivePace!)
            }
        }
    }
    
    func updatePedometerLabel(pedometerData: CMPedometerData) {
        let totalNumSteps = pedometerData.numberOfSteps.stringValue
        var cadence = "0"
        if let currCadence = pedometerData.currentCadence {
            cadence = String(format: "%.3f", currCadence.floatValue * 60.0)
        }
        print(String(describing: "Number of steps: \(totalNumSteps)\n Steps per minute: \(cadence)"))
    }
    
    
    func calculateSteps() {
        pedometer.startUpdates(from: Date()) { (data, error) in
            guard let pedometerData = data, error == nil else { return }
            print(pedometerData.averageActivePace!)
        }
    }
    
    func startAccelerometer() {
        motion.accelerometerUpdateInterval = 0.01
        motion.startAccelerometerUpdates(to: OperationQueue.current!) {
            (data, error) in
            print("Hi")
            if let trueData = data {
                let x = trueData.acceleration.x * 9.8
                let y = trueData.acceleration.y * 9.8
                let z = trueData.acceleration.z * 9.8
                let absolute = sqrt(pow(x, 2) + pow(y * 9.8, 2) + pow(z * 9.8, 2)) - 9.8
                let absStr = String(format: "%.3f", absolute)
                print("Acceleration: ", absStr)
            }
        }
    }
    func startMotionCapture() {
        motion.deviceMotionUpdateInterval  = 0.01
        motion.startDeviceMotionUpdates(to: OperationQueue.current!) {
            (data, error) in
            if let trueData = data {
                let x = String(format: "%.3f", trueData.attitude.pitch)
                let y = String(format: "%.3f", trueData.attitude.roll)
                let z = String(format: "%.3f", trueData.attitude.yaw)
                print("x: \(x)\ny: \(y)\nz: \(z)\n")
            }
        }
    }
}
