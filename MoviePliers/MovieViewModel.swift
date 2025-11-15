import AVFoundation
import AppKit

@Observable
class MovieViewModel: Identifiable {
    var id: UUID
    
    var movieModel: MovieModel?
    
    init(movie: AVMutableMovie? = nil, url: URL? = nil, id: UUID? = nil) {
        if let id {
            self.id = id
        }
        else {
            self.id = UUID()
        }
        
        if let movie {
            self.movieModel = MovieModel(movie: movie, id: self.id, url: url)
            self.movieModel!.setParent(self)
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
        return self._playerItem
    }
    
    // player
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
    
    var currentTime: Double {
        if let player = self.player {
            return player.currentTime().seconds
        }
        return 0.0
    }
    
    func seek(to seconds: Double) {
        if let player = self.player {
            // TODO: use movie's favorite (biggest?) timescale
            player.seek(to: CMTime(seconds: seconds, preferredTimescale: 60000))
        }
    }
    
    var duration: Double {
        if let playerItem = self.playerItem {
            return playerItem.duration.seconds
        }
        return 0.0
    }
    
    func movieDidChange() {
        if let player = self.player {
            if let movie = self.movieModel?.movie {
                let newPlayerItem = AVPlayerItem(asset: movie)
                player.replaceCurrentItem(with: newPlayerItem)
            }
            else {
                player.replaceCurrentItem(with: nil)
            }
        }
    }
}
