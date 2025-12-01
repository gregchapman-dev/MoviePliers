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
    
    func seek(to time: CMTime) async {
        if let player = self.player {
            self.enablePeriodicTimeObserver = false
            await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            self.currentTime = player.currentTime()
            self.enablePeriodicTimeObserver = true
        }
    }
    
    func getNextInterestingTime(after currentTime: CMTime) async throws -> CMTime {
        return try await self.movieModel?.movie?.getNextInterestingTime(after: currentTime) ?? currentTime
    }
        
    func getPreviousInterestingTime(before currentTime: CMTime) async throws -> CMTime {
        return try await self.movieModel?.movie?.getPreviousInterestingTime(before: currentTime) ?? currentTime
    }
        
    func stepForward() async throws {
        if self.player != nil && self.playerItem != nil {
            let nextTime = try await getNextInterestingTime(after: self.currentTime)
            await self.seek(to: nextTime)
        }
    }
    
    func stepBackward() async throws {
        if self.player != nil && self.playerItem != nil {
            let nextTime = try await getPreviousInterestingTime(before: self.currentTime)
            await self.seek(to: nextTime)
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
        if self.movieModel == nil || self.movieModel!.movie == nil {
            self.selection = nil
        }
        else {
            self.selection = CMTimeRange(start: .zero, end: self.movieModel!.movie!.duration)
        }
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
}
