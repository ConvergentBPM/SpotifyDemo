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

var firstTime : Bool = true
var wasPlayingWhenDisappear : Bool = true

class PlayVC: UIViewController, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    @IBOutlet weak var acceleration: UILabel!
    @IBOutlet weak var deviceMotion: UILabel!
    
    @IBOutlet weak var pedometerLabel: UILabel!
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
    
    var userPlaylists = SongDatabase()
    var tempURLs = [URL]()
    var isChangingProgress: Bool = false
    let audioSession = AVAudioSession.sharedInstance()
    var pedometer = StepTracker()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if(SPTAudioStreamingController.sharedInstance() == nil){
            self.trackTitle.text = "Nothing Playing"
            self.artistTitle.text = ""
        }
        else {
            updateUI()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @IBAction func rewind(_ sender: UIButton) {
        SPTAudioStreamingController.sharedInstance().skipPrevious(nil)
        playPauseButton!.setTitle("Pause", for: .normal)
    }
    
    @IBAction func playPause(_ sender: UIButton) {
        SPTAudioStreamingController.sharedInstance().setIsPlaying(!SPTAudioStreamingController.sharedInstance().playbackState.isPlaying, callback: nil)
        if (SPTAudioStreamingController.sharedInstance()?.playbackState.isPlaying)! {
            playPauseButton.setTitle("Play", for: .normal)
        }
        else{
            playPauseButton.setTitle("Pause", for: .normal)
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
            default:
                print("action not caught")
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didChangePosition position: TimeInterval) {
        if self.isChangingProgress {
            return
        }
        if let currentTrack = SPTAudioStreamingController.sharedInstance().metadata.currentTrack {
            let positionDouble = Double(position)
            let durationDouble = currentTrack.duration
            self.progressSlider.value = Float(positionDouble / durationDouble)
        }
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didStartPlayingTrack trackUri: String) {
        print("Starting \(trackUri)")
        print("Source \(String(describing: SPTAudioStreamingController.sharedInstance().metadata.currentTrack?.playbackSourceUri))")
        // If context is a single track and the uri of the actual track being played is different
        // than we can assume that relink has happended.
        let isRelinked = SPTAudioStreamingController.sharedInstance().metadata.currentTrack!.playbackSourceUri.contains("spotify:track") && !(SPTAudioStreamingController.sharedInstance().metadata.currentTrack!.playbackSourceUri == trackUri)
        print("Relinked \(isRelinked)")
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didStopPlayingTrack trackUri: String) {
        print("Finishing: \(trackUri)")
    }
    
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController) {
        self.updateUI()
        let playListRequest = try! SPTPlaylistList.createRequestForGettingPlaylists(forUser: AuthService.instance.sessionuserId ?? "", withAccessToken: AuthService.instance.sessiontokenId ?? "")
        Alamofire.request(playListRequest).response { response in
            print(response)
            let list = try! SPTPlaylistList(from: response.data, with: response.response)
            var index = 0
            for playList in list.items  {
                index += 1
                if let playlist = playList as? SPTPartialPlaylist {
                    self.getTracksFromPlayList(url: playlist.uri) { result in
                        if index == list.items.count {
                            self.pedometer.getStepsPerMinute(changeInCadence: 20, callback: self.handleStepsPerMinute)
                        }
                    }
                    SPTAudioStreamingController.sharedInstance()?.setShuffle(true, callback: nil)
                }
            }
        }
    }
    
    func handleStepsPerMinute(cadence: Double) {
        let (closestPlaylist, closestSong) = self.userPlaylists.getSongForBPM(bpm: cadence)
        print("closest song with bpm ", cadence, " \(closestSong.name),  \(closestSong.bpm)" )
        self.playThisSong(song: closestSong, playlistURI: closestPlaylist.url.absoluteString)
    }
    
    func playThisSong(song : Song){
        let playlistURI = (SPTAudioStreamingController.sharedInstance().metadata.currentTrack?.playbackSourceUri)!
        self.playThisSong(song: song, playlistURI: playlistURI)
    }
    
    func playThisSong(song : Song, playlistURI : String){
        var isPlayingSameSong = false
        if let controller = SPTAudioStreamingController.sharedInstance() {
            if let data = controller.metadata, let currentTrack = data.currentTrack {
                isPlayingSameSong = currentTrack.playbackSourceUri == playlistURI
            }
            if !isPlayingSameSong {
                controller.playSpotifyURI("\(String(describing: playlistURI))", startingWith: (UInt)(song.playListIndex), startingWithPosition: 0) { error in
                    if error != nil {
                        print("*** failed to play: \(String(describing: error))")
                        return
                    }
                }
            }
        }
    }
    
    func setUpPlaylist (url : URL, _ completion: @escaping (Playlist) -> Void){
        var dataPoints = [Double : URL]()
        let playList = Playlist(url: url)
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
        let playList = Playlist(url: url)
        let playListRequest = try! SPTPlaylistSnapshot.createRequestForPlaylist(withURI: URL(string: newUrl), accessToken: AuthService.instance.sessiontokenId ?? "")
        
        Alamofire.request(playListRequest).responseJSON(completionHandler: { response in
            let list = try! SPTPlaylistSnapshot(from: response.data, with: response.response)
            self.getTracksFrom(page: list.firstTrackPage, completion: { response in
                var index : Int = 0
                for track in response {
                    self.getBPMForTrack(url: track.uri){ result in
                        index += 1
                        dataPoints[result] = track.uri!
                        let song : Song = Song(url: track.uri!, name: track.name!, artist: track.artists!, bpm: result, date: track.addedAt!)
                        playList.append(song: song)
                        if(index == response.count){
                            playList.setSongIndexes()
                            self.userPlaylists.append(playlist: playList)
                            completion(dataPoints)
                        }
                    }
                }
            })
        })
    }
    
    func getTracksFrom(page:SPTListPage, completion: @escaping (_ success: [SPTPlaylistTrack]) -> ()) {
        if(page.hasNextPage){
            var allTracks = [SPTPlaylistTrack]()
            if let items = page.items as? [SPTPlaylistTrack] {
                for t in items {
                    allTracks.append(t)
                }
                self.getNextPage(page: page, completion: { results in
                    for t in results {
                        allTracks.append(t)
                    }
                    completion(allTracks)
                })
            } else {
                completion(allTracks)
            }
        }
        else {
            var allTracks = [SPTPlaylistTrack]()
            if let items = page.items as? [SPTPlaylistTrack] {
                for t in items {
                    allTracks.append(t)
                }
            }
            completion(allTracks)
        }
    }
    
    func getNextPage(page : SPTListPage, completion: @escaping (_ success: [SPTPlaylistTrack]) -> ()) {
        page.requestNextPage(withAccessToken: AuthService.instance.sessiontokenId!) { (error, data) in
            guard let p = data as? SPTListPage else {return}
            if let items = p.items as? [SPTPlaylistTrack] {
                completion(items)
            } else {
                completion([SPTPlaylistTrack]())
            }
        }
    }
    
    
    func getBPMForTrack(url : URL, _ completion: @escaping (Double) -> Void) {
        let s : String = url.absoluteString
        let trackID = s.components(separatedBy: ":")[2]
        let request = "https://api.spotify.com/v1/audio-features/\(trackID)?access_token=\(AuthService.instance.sessiontokenId!)"
        Alamofire.request(request).responseJSON (completionHandler: { response in
            if let result = response.result.value as?  [String: Any] {
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
            if let result =  response.result.value as? [String: Any] {
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


class Song : Comparable {
    var url : URL
    var name : String = String()
    var artist : [Any] = [Any]()
    var bpm : Double = Double()
    var dateAdded: Date = Date()
    var playListIndex : Int
    
    init(url: URL, name : String, artist: [Any], bpm: Double, date: Date) {
        self.url = url
        self.name = name
        self.artist = artist
        self.bpm = bpm
        self.dateAdded = date
        self.playListIndex = -1
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

class Playlist {
    var songs : [Song]
    var url : URL
    
    init(url : URL) {
        self.songs = [Song]()
        self.url = url
    }
    
    func append(song : Song) {
        self.songs.append(song)
        self.sort()
    }
    
    func size() -> Int {
        return songs.count
    }
    
    func getSong(url : URL) -> Song {
        for song in songs {
            if(song.url == url){
                return song
            }
        }
        return Song(url: URL(string: "")!, name: "", artist: [Any](), bpm: 0.0, date: Date())
    }
    func sort() {
        self.songs.sort()
    }
    func getSongForBPM(bpm : Double) -> Song {
        if bpm <= self.songs[0].bpm {
            return self.songs[0]
        }
        if bpm >= self.songs[self.songs.count - 1].bpm {
            return self.songs[self.songs.count - 1]
        }
        var start = 0
        var end = self.songs.count - 1
        while start <= end {
            let mid = start + (end - start) / 2
            if bpm == self.songs[mid].bpm {
                return self.songs[mid]
            }
            if bpm < self.songs[mid].bpm {
                end = mid - 1
            } else {
                start = mid + 1
            }
        }
        return (self.songs[start].bpm - bpm) < (bpm - self.songs[end].bpm) ? self.songs[start] : self.songs[end]
    }
    func setSongIndexes() {
        self.songs.sort(){$0.dateAdded < $1.dateAdded}
        for i in 0..<self.songs.count {
            self.songs[i].playListIndex = i
        }
        self.sort()
    }
}

class SongDatabase {
    var playlists : [Playlist] = [Playlist]()
    
    func append(playlist : Playlist) {
        self.playlists.append(playlist)
    }
    
    func getSongForBPM(bpm : Double) -> (Playlist, Song) {
        var bestSongs : [(Playlist, Song)] = [(Playlist, Song)]()
        for playlist in self.playlists {
            bestSongs.append((playlist, playlist.getSongForBPM(bpm: bpm)))
        }
        var (bestPlaylist, bestSong) = bestSongs[0]
        for (playlist, song) in bestSongs {
            if (abs(song.bpm - bpm) < abs(bestSong.bpm - bpm)) {
                bestSong = song
                bestPlaylist = playlist
            }
        }
        return (bestPlaylist, bestSong)
    }
}
