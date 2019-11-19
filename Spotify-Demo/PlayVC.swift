//
//  PlayVC.swift
//  Spotify-Demo
//
// Copyright © 2019 All rights reserved.
//


import UIKit
import AudioToolbox
import AVFoundation
import CoreMotion
import MediaPlayer

var firstTime : Bool = true
var wasPlayingWhenDisappear : Bool = true
var songs = Playlist()

class PlayVC: UIViewController, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    @IBOutlet weak var playPauseButton: UIButton!
    
    @IBOutlet weak var trackTitle: UILabel!
    @IBOutlet weak var prevButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var coverView: UIImageView!
    @IBOutlet weak var coverView2: UIImageView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var playbackSourceTitle: UILabel!
    @IBOutlet weak var artistTitle: UILabel!
    
    var userPlaylists = [Playlist]()
    var tempURLs = [URL]()
    var nowPlayingInfo = [String:Any]()
    var isChangingProgress: Bool = false
    let audioSession = AVAudioSession.sharedInstance()
    let playListNum : Int = 4

    override func viewDidLoad() {
        super.viewDidLoad()
        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(screenEdgeSwiped))
        edgePan.edges = .bottom
        view.addGestureRecognizer(edgePan)
        
        if(SPTAudioStreamingController.sharedInstance() == nil){
            self.trackTitle.text = "Nothing Playing"
            self.artistTitle.text = ""
            setupRemoteTransportControls()
            setupNotificationView()
        }
        else {
            updateUI()
            setupRemoteTransportControls()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.handleNewSession()
        print("session: \(AuthService.instance.sessiontokenId ?? "")")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        wasPlayingWhenDisappear = (SPTAudioStreamingController.sharedInstance()?.playbackState.isPlaying)!
    }
    
    func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget {_ in
                SPTAudioStreamingController.sharedInstance().setIsPlaying(!SPTAudioStreamingController.sharedInstance().playbackState.isPlaying, callback: nil)
                return .success
            }

            // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget {_ in
            SPTAudioStreamingController.sharedInstance().setIsPlaying(!SPTAudioStreamingController.sharedInstance().playbackState.isPlaying, callback: nil)
                return .success
            }
        commandCenter.nextTrackCommand.addTarget {_ in
                    SPTAudioStreamingController.sharedInstance().skipNext(nil)
            self.playPauseButton!.setTitle("Pause", for: .normal)
            return .success
        }
        commandCenter.previousTrackCommand.addTarget {_ in
                     SPTAudioStreamingController.sharedInstance().skipPrevious(nil)
            self.playPauseButton!.setTitle("Pause", for: .normal)
            return .success
        }
    }
    
    func setupNotificationView(){
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = SPTAudioStreamingController.sharedInstance()?.metadata.currentTrack?.name
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = SPTAudioStreamingController.sharedInstance()?.metadata.currentTrack?.albumName
        nowPlayingInfo[MPMediaItemPropertyArtist] = SPTAudioStreamingController.sharedInstance()?.metadata.currentTrack?.artistName
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = SPTAudioStreamingController.sharedInstance()?.metadata.currentTrack?.duration
        
        let url : URL = URL(string: (SPTAudioStreamingController.sharedInstance()?.metadata.currentTrack?.albumCoverArtURL)!)!
        let data: Data = try! Data(contentsOf: url)
        let image : UIImage = UIImage(data: data)!
       nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork.init(boundsSize: image.size, requestHandler: { (size) -> UIImage in
                    return image
            })
        
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @IBAction func rewind(_ sender: UIButton) {
        SPTAudioStreamingController.sharedInstance().skipPrevious(nil)
        playPauseButton!.setTitle("Pause", for: .normal)
    }
    
    func playPauseAction(){
SPTAudioStreamingController.sharedInstance().setIsPlaying(!SPTAudioStreamingController.sharedInstance().playbackState.isPlaying, callback: nil)
        if (SPTAudioStreamingController.sharedInstance()?.playbackState.isPlaying)! {
            playPauseButton.setTitle("Play", for: .normal)
        }
        else{
            playPauseButton.setTitle("Pause", for: .normal)
        }
    }
    @IBAction func playPause(_ sender: UIButton) {
        playPauseAction()
//      SPTAudioStreamingController.sharedInstance().setIsPlaying(!SPTAudioStreamingController.sharedInstance().playbackState.isPlaying, callback: nil)
//        if (SPTAudioStreamingController.sharedInstance()?.playbackState.isPlaying)! {
//            playPauseButton.setTitle("Play", for: .normal)
//        }
//        else{
//            playPauseButton.setTitle("Pause", for: .normal)
//        }
    }
    
    @objc func screenEdgeSwiped(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        if recognizer.state == .recognized {
            print("Screen edge swiped!")
        }
    }
    
    @IBAction func fastForward(_ sender: UIButton) {
        SPTAudioStreamingController.sharedInstance().skipNext(nil)
        playPauseButton!.setTitle("Pause", for: .normal)
    }
    
    @IBAction func seekValueChanged(_ sender: UISlider) {
        self.isChangingProgress = false
        let dest = SPTAudioStreamingController.sharedInstance().metadata!.currentTrack!.duration * Double(self.progressSlider.value)
        SPTAudioStreamingController.sharedInstance().seek(to: dest, callback: nil)
    }
    
    @IBAction func logoutClicked(_ sender: UIButton) {
        if (SPTAudioStreamingController.sharedInstance() != nil) {
            SPTAudioStreamingController.sharedInstance().logout()
        }
        else {
            _ = self.navigationController!.popViewController(animated: true)
        }
        
    }
    
    @IBAction func proggressTouchDown(_ sender: UISlider) {
        self.isChangingProgress = true
    }
    
    func applyBlur(on imageToBlur: UIImage, withRadius blurRadius: CGFloat) -> UIImage {
        let originalImage = CIImage(cgImage: imageToBlur.cgImage!)
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(originalImage, forKey: "inputImage")
        filter?.setValue(blurRadius, forKey: "inputRadius")
        let outputImage = filter?.outputImage
        let context = CIContext(options: nil)
        let outImage = context.createCGImage(outputImage!, from: outputImage!.extent)
        let ret = UIImage(cgImage: outImage!)
        return ret
    }
    
    func updateUI() {
        _ = SPTAuth.defaultInstance()
        if SPTAudioStreamingController.sharedInstance().metadata == nil || SPTAudioStreamingController.sharedInstance().metadata.currentTrack == nil {
            self.coverView.image = nil
            self.coverView2.image = nil
            return
        }
        self.spinner.startAnimating()
        self.nextButton.isEnabled = SPTAudioStreamingController.sharedInstance().metadata.nextTrack != nil
        self.prevButton.isEnabled = SPTAudioStreamingController.sharedInstance().metadata.prevTrack != nil
        self.trackTitle.text = SPTAudioStreamingController.sharedInstance().metadata.currentTrack?.name
        
        self.artistTitle.text = SPTAudioStreamingController.sharedInstance().metadata.currentTrack?.artistName
        self.playbackSourceTitle.text = SPTAudioStreamingController.sharedInstance().metadata.currentTrack?.playbackSourceName
        
        if(!firstTime){
            audioStreaming(SPTAudioStreamingController.sharedInstance(), didChangePosition: SPTAudioStreamingController.sharedInstance().playbackState.position)
            isChangingProgress = false
        }
        let imageURL = (SPTAudioStreamingController.sharedInstance().metadata.currentTrack?.albumCoverArtURL)
        DispatchQueue.global().async {
            do {
                let imageData = try Data(contentsOf: URL(string: imageURL!)!, options: [])
                let image = UIImage(data: imageData)
                DispatchQueue.main.async {
                    self.spinner.stopAnimating()
                    self.coverView.image = image
                    if image == nil {
                        print("couldn't load cover image with error")
                    }
                }
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
 
    func handleNewSession() {
        do {
            if (SPTAudioStreamingController.sharedInstance()!.loggedIn){
                SPTAudioStreamingController.sharedInstance().delegate = self
                SPTAudioStreamingController.sharedInstance().playbackDelegate = self
                SPTAudioStreamingController.sharedInstance().diskCache = SPTDiskCache()
                let positionDouble = Double((SPTAudioStreamingController.sharedInstance()?.playbackState.position)!)
                let durationDouble = Double(SPTAudioStreamingController.sharedInstance().metadata.currentTrack!.duration)
                self.progressSlider.value = Float(positionDouble / durationDouble)
                return
                
            }
            else {
                try SPTAudioStreamingController.sharedInstance().start(withClientId: SPTAuth.defaultInstance().clientID, audioController: nil, allowCaching: true)
                SPTAudioStreamingController.sharedInstance().delegate = self
                SPTAudioStreamingController.sharedInstance().playbackDelegate = self
                SPTAudioStreamingController.sharedInstance().diskCache = SPTDiskCache() /* capacity: 1024 * 1024 * 64 */
                SPTAudioStreamingController.sharedInstance().login(withAccessToken: AuthService.instance.sessiontokenId ?? "")
            }
        } catch let error {
            let alert = UIAlertController(title: "Error init", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(alert, animated: true, completion: {})
            self.closeSession()
        }
    }
    
    func closeSession() {
        do {
            try SPTAudioStreamingController.sharedInstance().stop()
            SPTAuth.defaultInstance().session = nil
            _ = self.navigationController!.popViewController(animated: true)
        } catch let error {
            let alert = UIAlertController(title: "Error deinit", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(alert, animated: true, completion: { })
        }
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didReceiveMessage message: String) {
        let alert = UIAlertController(title: "Message from Spotify", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(alert, animated: true, completion: {  })
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didChangePlaybackStatus isPlaying: Bool) {
        if isPlaying {
            self.activateAudioSession()
        }
        else {
            self.deactivateAudioSession()
        }
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didChange metadata: SPTPlaybackMetadata) {
        self.updateUI()
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didReceive event: SpPlaybackEvent, withName name: String) {
        print("didReceivePlaybackEvent: \(event) \(name)")
        print("isPlaying=\(SPTAudioStreamingController.sharedInstance().playbackState.isPlaying) isRepeating=\(SPTAudioStreamingController.sharedInstance().playbackState.isRepeating) isShuffling=\(SPTAudioStreamingController.sharedInstance().playbackState.isShuffling) isActiveDevice=\(SPTAudioStreamingController.sharedInstance().playbackState.isActiveDevice) positionMs=\(SPTAudioStreamingController.sharedInstance().playbackState.position)")
    }
    
    func audioStreamingDidLogout(_ audioStreaming: SPTAudioStreamingController) {
        self.closeSession()
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didReceiveError error: Error?) {
        print("didReceiveError: \(error!.localizedDescription)")
        let alert = UIAlertController(title: "Error", message: "\(error!.localizedDescription)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            switch action.style{
            case .default:
                print("default")
            case .cancel:
                print("cancel")
            case .destructive:
                print("destructive")
            }}))
        self.present(alert, animated: true, completion: nil)
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didChangePosition position: TimeInterval) {
        if self.isChangingProgress {
            return
        }
        let positionDouble = Double(position)
        let durationDouble = Double(SPTAudioStreamingController.sharedInstance().metadata.currentTrack!.duration)
        self.progressSlider.value = Float(positionDouble / durationDouble)
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didStartPlayingTrack trackUri: String) {
        print("Starting \(trackUri)")
        print("Source \(String(describing: SPTAudioStreamingController.sharedInstance().metadata.currentTrack?.playbackSourceUri))")
        // If context is a single track and the uri of the actual track being played is different
        // than we can assume that relink has happended.
        let isRelinked = SPTAudioStreamingController.sharedInstance().metadata.currentTrack!.playbackSourceUri.contains("spotify:track") && !(SPTAudioStreamingController.sharedInstance().metadata.currentTrack!.playbackSourceUri == trackUri)
        print("Relinked \(isRelinked)")
                                        self.setupNotificationView()
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didStopPlayingTrack trackUri: String) {
        print("Finishing: \(trackUri)")
    }
    
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController) {
        self.updateUI()
        var numPlayList : Int = 0
        let playListRequest = try! SPTPlaylistList.createRequestForGettingPlaylists(forUser: AuthService.instance.sessionuserId ?? "", withAccessToken: AuthService.instance.sessiontokenId ?? "")
        Alamofire.request(playListRequest)
            .response { response in
                print(response)
                let list = try! SPTPlaylistList(from: response.data, with: response.response)
                for playList in list.items  {
                    if let playlist = playList as? SPTPartialPlaylist {
                        print(playlist.name!)
                        //                                                self.setUpPlaylist(url: playlist.uri, {res in
                        //                                                    self.userPlaylists.append(res)
                        //                                                })
                        if(numPlayList == self.playListNum){
                            self.getTracksFromPlayList(url: playlist.uri) { result in
                                let dataPoints = result
                                print(dataPoints.count)
                                for song in songs.songs{
                                    print("\(song.bpm), \(song.url), \(song.name), \(song.dateAdded)")
                                }
                                
                                let x = 184.02
                                let closestUrl : String = songs.getSongForBPM(bpm: x).url.absoluteString
                                print(closestUrl)
                                
                                let closestSong : Song = songs.getSongForBPM(bpm: x)
                                print("closest song with bpm ", x, " \(closestSong.name),  \(closestSong.bpm)" )
                                self.playThisSong(song: closestSong, playlistURI: playlist.uri.absoluteString)
                            }
                            
                            SPTAudioStreamingController.sharedInstance()?.setShuffle(true, callback: nil)
                        }
                        numPlayList += 1
                    }
                    else {
                        print(playList)
                    }
                }}
    }
    
    func playThisSong(song : Song){
        let playlistURI = (SPTAudioStreamingController.sharedInstance().metadata.currentTrack?.playbackSourceUri)!
        self.playThisSong(song: song, playlistURI: playlistURI)
    }
    
    func playThisSong(song : Song, playlistURI : String){
        songs.songs.sort(){ $0.dateAdded < $1.dateAdded}
        let i : Int = songs.songs.index(of: song)!
        SPTAudioStreamingController.sharedInstance().playSpotifyURI("\(String(describing: playlistURI))", startingWith: (UInt)(i), startingWithPosition: 0) { error in
            if error != nil {
                print("*** failed to play: \(String(describing: error))")
                return
            }
        }
    }
    
    func setUpPlaylist (url : URL, _ completion: @escaping (Playlist) -> Void){
        var dataPoints = [Double : URL]()
        let playList = Playlist()
        let newUrl : String = "spotify:user:" + url.absoluteString
        let playListRequest = try! SPTPlaylistSnapshot.createRequestForPlaylist(withURI: URL(string: newUrl), accessToken: AuthService.instance.sessiontokenId ?? "")
        
        Alamofire.request(playListRequest).responseJSON(completionHandler: { response in
            let list = try! SPTPlaylistSnapshot(from: response.data, with: response.response)
            self.getTracksFrom(page: list.firstTrackPage, completion: { response in
                print(response.count)
                var index : Int = 0
                for track in response {
                    self.getBPMForTrack(url: track.uri){ result in
                        dataPoints[result] = track.uri!
                        index += 1
                        let song : Song = Song(url: track.uri!, name: track.name!, artist: track.artists!, bpm: result, date: track.addedAt!)
                        playList.songs.append(song)
                        if(index == response.count){
                            completion(playList)
                        }
                    }}
            })
        })
    }
    
    
    func getTracksFromPlayList(url : URL, _ completion: @escaping ([Double : URL]) -> Void){
        var dataPoints = [Double : URL]()
        let newUrl : String = "spotify:user:" + url.absoluteString
        let playListRequest = try! SPTPlaylistSnapshot.createRequestForPlaylist(withURI: URL(string: newUrl), accessToken: AuthService.instance.sessiontokenId ?? "")
        
        Alamofire.request(playListRequest).responseJSON(completionHandler: { response in
            let list = try! SPTPlaylistSnapshot(from: response.data, with: response.response)
            self.getTracksFrom(page: list.firstTrackPage, completion: { response in
                
                print(response.count)
                var index : Int = 0
                for track in response {
                    self.getBPMForTrack(url: track.uri){ result in
                        index += 1
                        dataPoints[result] = track.uri!
                        let song : Song = Song(url: track.uri!, name: track.name!, artist: track.artists!, bpm: result, date: track.addedAt!)
                        songs.append(song: song)
                        if(index == response.count){
                            print("Songs size: ", songs.songs.count)
                            songs.songs.sort(){ $0.dateAdded < $1.dateAdded}
                            completion(dataPoints)
                        }
                    }}
            })
        })
    }
    
    func getTracksFrom(page:SPTListPage, completion: @escaping (_ success: [SPTPlaylistTrack]) -> ()) {
        if(page.hasNextPage){
            let items = page.items as! [SPTPlaylistTrack]
            var allTracks = [SPTPlaylistTrack]()
            for t in items {
                allTracks.append(t)
            }
            self.getNextPage(page: page, completion: { results in
                for t in results {
                    allTracks.append(t)
                }
                completion(allTracks)
            })
        }
        else {
            let items = page.items as! [SPTPlaylistTrack]
            var allTracks = [SPTPlaylistTrack]()
            for t in items {
                allTracks.append(t)
            }
            completion(allTracks)
        }
    }
    
    func getNextPage(page : SPTListPage, completion: @escaping (_ success: [SPTPlaylistTrack]) -> ()) {
        page.requestNextPage(withAccessToken: AuthService.instance.sessiontokenId!) { (error, data) in
            guard let p = data as? SPTListPage else {return}
            let items = p.items as! [SPTPlaylistTrack]
            completion(items)
        }
    }
    
    func getBPMForTrack(url : URL, _ completion: @escaping (Double) -> Void) {
        let s : String = url.absoluteString
        let trackID = s.components(separatedBy: ":")[2]
        let request = "https://api.spotify.com/v1/audio-features/\(trackID)?access_token=\(AuthService.instance.sessiontokenId!)"
        Alamofire.request(request).responseJSON (completionHandler: { response in
            if let result =  response.result.value as?  [String: Any] {
                if(result["tempo"] as? Double ?? 0.0 == 0.0){
                    print(result)
                }
                completion(result["tempo"] as? Double ?? 0.0)
            }
        })
    }
    
    func getNameForTrack(url : URL, _ completion: @escaping (String) -> Void){
        let s : String = url.absoluteString
        let trackID = s.components(separatedBy: ":")[2]
        let request = "https://api.spotify.com/v1/tracks/\(trackID)?access_token=\(AuthService.instance.sessiontokenId!)"
        Alamofire.request(request).responseJSON (completionHandler: { response in
            if let result =  response.result.value as?  [String: Any] {
                completion(result["name"] as? String ?? "song")
            }
        })
    }
    
    func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        }
        catch let error {
            print(error.localizedDescription)
        }
    }
    
    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        }
        catch let error {
            print(error.localizedDescription)
        }
    }
}

class Song : Comparable{
    var url : URL
    var name : String = String()
    var artist : [Any] = [Any]()
    var bpm : Double = Double()
    var dateAdded: Date = Date()
    
    init(url: URL, name : String, artist: [Any], bpm: Double, date: Date) {
        self.url = url
        self.name = name
        self.artist = artist
        self.bpm = bpm
        self.dateAdded = date
    }
    static func < (lhs: Song, rhs: Song) -> Bool {
        return lhs.bpm < rhs.bpm
    }
    
    static func > (lhs: Song, rhs: Song) -> Bool {
        return lhs.bpm > rhs.bpm
    }
    static func == (lhs: Song, rhs: Song) -> Bool {
        return lhs.bpm == rhs.bpm
    }
    
}

class Playlist{
    var songs : [Song] = [Song]()
    
    func append(song : Song){
        songs.append(song)
    }
    
    func size() -> Int{
        return songs.count
    }
    
    func getSong(url : URL) -> Song{
        for song in songs {
            if(song.url == url){
                return song
            }
        }
        return Song(url: URL(string: "")!, name: "", artist: [Any](), bpm: 0.0, date: Date())
    }
    func sort(){
        songs.sort()
    }
    func getSongForBPM(bpm : Double) -> Song{
        var bestSong : Song = songs[0]
        var prevDiff : Double = bestSong.bpm - bpm
        for song in songs.sorted(){
            if(abs(song.bpm - bpm) < abs(bestSong.bpm - bpm)){
                bestSong = song
            }
            if(song.bpm > bpm && (song.bpm - bpm) < prevDiff){
                return bestSong
            }
            prevDiff = abs(song.bpm - bpm)
        }
        return bestSong
    }
}
