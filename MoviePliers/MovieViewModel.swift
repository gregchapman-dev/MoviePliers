import AVFoundation
import AppKit

@Observable
class MovieViewModel: Identifiable {
    var id: UUID
    var movieModel: MovieModel?
    var selection: CMTimeRange?
    var interestingTimes: [CMTime]

    init(movie: AVMutableMovie? = nil, url: URL? = nil, id: UUID? = nil) {
        if let id {
            self.id = id
        }
        else {
            self.id = UUID()
        }
        
        self.currentTime = .zero
        self.enablePeriodicTimeObserver = true
        self.interestingTimes = []
        
        if let movie {
            self.movieModel = MovieModel(movie: movie, id: self.id, url: url, parent: self)
        }
    }
    
    deinit {
        if let timeObserver {
            self.player!.removeTimeObserver(timeObserver)
        }
    }
    
    // playerItem
    var _playerItem: AVPlayerItem?
    var playerItem: AVPlayerItem? {
        if self._playerItem != nil {
            return self._playerItem
        }
        if self.movieModel?.movie == nil {
            return nil
        }
        self._playerItem = AVPlayerItem(asset: self.movieModel!.movie!)
        self.currentTime = .zero
        return self._playerItem
    }
    
    // player
    var timeObserver: Any?
    var enablePeriodicTimeObserver: Bool
    var _player: AVPlayer?
    var player: AVPlayer? {
        if self._player != nil {
            return self._player
        }
        if self.playerItem == nil {
            // couldn't create playerItem yet (no movie)
            return nil
        }
        self._player = AVPlayer(playerItem: self.playerItem!)
        self.currentTime = .zero
        
        self.timeObserver = self._player!.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main) { [weak self] time in
                if self?.player != nil {
                    // we only update time when we are enabled
                    if !self!.enablePeriodicTimeObserver {
                        return
                    }
                    self?.currentTime = time
                }
            }

        return self._player
    }
    
    var windowTitle: String {
        if let url = movieModel?.url {
            return url.lastPathComponent
        }
        return "New Movie"
    }
    
    var isModified: Bool {
        return self.movieModel?.isModified ?? false
    }
    
    var isPlaying: Bool {
        if let player = self.player {
            return player.timeControlStatus == .playing
        }
        return false
    }
    
    func togglePlayPause() {
        if let player = self.player {
            if player.timeControlStatus == .paused {
                player.play()
            }
            else {
                player.pause()
            }
        }
    }
    
    var currentTime: CMTime
    
    func seek(to time: CMTime) {
        if let player = self.player {
            self.enablePeriodicTimeObserver = false
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                self.currentTime = player.currentTime()
                self.enablePeriodicTimeObserver = true
            }
        }
    }
    
    func getNextInterestingTime(_ currentTime: CMTime) -> CMTime {
        if currentTime < .zero {
            // shouldn't ever happen, but we assume it below...
            return self.interestingTimes.first ?? .zero
        }

        if currentTime >= self.duration {
            return self.interestingTimes.last ?? self.duration
        }
        
        if self.interestingTimes.isEmpty {
            // no video track sample times? Jump back by a quarter second.
            return currentTime + CMTime(seconds: 0.25, preferredTimescale: currentTime.timescale)
        }
        
        // Do it slow for now!
        for i in 1..<self.interestingTimes.count {
            if self.interestingTimes[i - 1] <= currentTime && currentTime < self.interestingTimes[i] {
                return self.interestingTimes[i]
            }
        }
        
        // Shouldn't get here. Jump back by a quarter second.
        return currentTime + CMTime(seconds: 0.25, preferredTimescale: currentTime.timescale)
    }
        
    func getPreviousInterestingTime(_ currentTime: CMTime) -> CMTime {
        if currentTime <= .zero {
            return self.interestingTimes.first ?? .zero
        }

        if currentTime > self.duration {
            // shouldn't ever happen, but we assume it below...
            return self.interestingTimes.last ?? self.duration
        }
        
        if self.interestingTimes.isEmpty {
            // no video track sample times? Jump back by a quarter second.
            return currentTime - CMTime(seconds: 0.25, preferredTimescale: currentTime.timescale)
        }
        
        // Do it slow for now!
        for i in 1..<self.interestingTimes.count {
            if self.interestingTimes[i - 1] < currentTime && currentTime <= self.interestingTimes[i] {
                return self.interestingTimes[i - 1]
            }
        }
        
        // Shouldn't get here. Jump back by a quarter second.
        return currentTime - CMTime(seconds: 0.25, preferredTimescale: currentTime.timescale)
    }
        
    func stepForward() {
        if self.player != nil && self.playerItem != nil {
            let nextTime = getNextInterestingTime(self.currentTime)
            self.seek(to: nextTime)
        }
    }
    
    func stepBackward() {
        if self.player != nil && self.playerItem != nil {
            let nextTime = getPreviousInterestingTime(self.currentTime)
            self.seek(to: nextTime)
        }
    }
    
    var duration: CMTime {
        if let playerItem = self.playerItem {
            return playerItem.duration
        }
        return .zero
    }
    
    // editing functions
    func selectAll() {
        self.selection = CMTimeRange(start: .zero, end: self.movieModel?.movie?.duration ?? .zero)
    }
    
    func select(_ selection: CMTimeRange) {
        if !selection.isValid {
            self.selection = nil
        }
        else {
            self.selection = selection
        }
    }
    
    func selectNone() {
        self.selection = nil
    }
    
    func copy() async {
        if self.movieModel != nil && self.selection != nil {
            await self.movieModel!.copy(fromTimeRange: self.selection!)
        }
    }
    
    func add() async {
        if self.movieModel != nil {
            await self.movieModel!.add()
        }
    }
    
    func movieDidChange() {
        if let player = self.player {
            if let movie = self.movieModel?.movie {
                let newPlayerItem = AVPlayerItem(asset: movie)
                player.replaceCurrentItem(with: newPlayerItem)
                // TODO: do thumb and player.currentTime() remain the same? If not, make it so.
            }
            else {
                player.replaceCurrentItem(with: nil)
            }
        }
    }
    
    func movieDidLoad() {
        self.interestingTimes = self.movieModel?.interestingTrackTimes ?? []
    }
}
