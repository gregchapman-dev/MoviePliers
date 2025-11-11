import AppKit
import AVFoundation

let qtMoviePasteboardType = NSPasteboard.PasteboardType(rawValue: "com.apple.quicktime-movie")

class MovieStore {
    struct MovieInfo {
        // the movie (always exists for an id)
        var movie: AVMutableMovie
        
        // url where the movie header is (either from file/open or from file/save/etc).
        // Doesn't exist for a new movie that has been edited, but not yet saved.
        var url: URL?
        
        // playerItem (created lazily, so might be nil
        var playerItem: AVPlayerItem?
        
        // player (created lazily)
        var player: AVPlayer?
        
        // current edit state
        var selection: CMTimeRange?
    }
    
    var movieInfos: [UUID:MovieInfo]
    init() {
        movieInfos = [:]
    }
    
    deinit {
        for id in movieInfos.keys {
            removeMovie(for: id)
        }
    }
    
    // store manipulations
    func newMovie() -> UUID {
        let id = UUID()
        newMovie(for: id)
        return id
    }

    func newMovie(for id: UUID) {
        let info = MovieInfo(movie: AVMutableMovie())
        movieInfos[id] = info
    }
    
    func openMovie(at url: URL) throws -> UUID {
        do {
            _ = url.startAccessingSecurityScopedResource()
            let mov = try AVMutableMovie(url: url, error: ())
            let id = UUID()
            let info = MovieInfo(movie: mov, url: url)
            movieInfos[id] = info
            return id
        }
        catch {
            print("fatal error: \(error)")
            throw error
        }
    }
    
//    func openImageSequence(at url: URL) throws -> UUID {
//        let mov = MutableMovieFromImageSequence(url: url)
//        let id = UUID()
//        movies[id] = mov
//        return id
//    }
    
    func removeMovie(for id: UUID) {
        if let info = movieInfos[id] {
            movieInfos.removeValue(forKey: id)
            if let url = info.url {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    func movie(for id: UUID) -> AVMutableMovie? {
        return movieInfos[id]?.movie
    }
    
    func asset(for id: UUID) -> AVAsset? {
        return movieInfos[id]?.movie as? AVAsset
    }
    
    func playerItem(for id: UUID) -> AVPlayerItem? {
        guard var info = movieInfos[id] else {
            return nil
        }
        
        if info.playerItem == nil {
            if let asset = asset(for: id) {
                info.playerItem = AVPlayerItem(asset: asset)
            }
        }
        return info.playerItem
    }
    
    func player(for id: UUID) -> AVPlayer? {
        guard var info = movieInfos[id] else {
            return nil
        }
            
        if info.player == nil {
            let item = playerItem(for: id)
            info.player = AVPlayer(playerItem: item!)
        }
        return info.player
    }
    
    func contains(_ id: UUID) -> Bool {
        return movieInfos.keys.contains(id)
    }
    
    // movie operations
    func windowTitle(for id: UUID) -> String {
        if let info = movieInfos[id] {
            if let url = info.url {
                return url.lastPathComponent
            }
        }
        return "New Movie"
    }
    
    // editing operations
    func movieIsModified(for id: UUID) -> Bool {
        guard let info = movieInfos[id] else {
            // non-existent movie is of course not modified
            return false
        }
        return info.movie.isModified
    }
    
    func selectAll(for id: UUID) {
        guard var info = movieInfos[id] else {
            return
        }
        info.selection = CMTimeRange(start: .zero, end: info.movie.duration)
    }
    
    func select(_ selection: CMTimeRange, for id: UUID) {
        guard var info = movieInfos[id] else {
            return
        }
        info.selection = selection
    }
    
    func copy(for id: UUID) {
        guard var info = movieInfos[id] else {
            return
        }
        do {
            let movieHeader: Data = try info.movie.makeMovieHeader(fileType: .mov)
            NSPasteboard.general.clearContents()
            let result = NSPasteboard.general.setData(movieHeader, forType: qtMoviePasteboardType)
            print("\(result)")
        }
        catch {
            print("failed to makeMovieHeader: \(error) from movieID: \(id)")
        }
    }
    
    func addAsync(for id: UUID) async {
        guard var info = movieInfos[id] else {
            return
        }
        guard let movieHeader: Data = NSPasteboard.general.data(forType: qtMoviePasteboardType) else {
            return
        }
        
        do {
            let pastedMovie = AVMovie(data: movieHeader)
            let tracks = try await pastedMovie.load(.tracks)
            let status = pastedMovie.status(of: .tracks)
            switch status {
            case .loaded:
                print("loaded value", pastedMovie.tracks)
            default:
                print("unexpected AVPlayerItemStatus: \(status)")
                return
            }
            for track in tracks {
                
            }
        }
        catch {
        }
    }
}
