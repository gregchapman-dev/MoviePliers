import AppKit
import AVFoundation

let qtMoviePasteboardType = NSPasteboard.PasteboardType(rawValue: "com.apple.quicktime-movie")

@Observable
class MovieInfo: Identifiable {
    // id has to be var (even though it is never set except in init) because we pass it around via focusedSceneValue
    var id: UUID
    
    var movie: AVMutableMovie?
    
    // url where the movie header is (either from file/open or from file/save/etc).
    // Doesn't exist for a new movie that has been edited, but not yet saved.
    var url: URL?
    
    // playerItem
    var _playerItem: AVPlayerItem?
    var playerItem: AVPlayerItem? {
        if self._playerItem != nil {
            return self._playerItem
        }
        if self.movie == nil {
            return nil
        }
        self._playerItem = AVPlayerItem(asset: self.movie!)
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

    // current edit state
    var selection: CMTimeRange?
    
    init(movie: AVMutableMovie? = nil, id: UUID? = nil, url: URL? = nil) {
        if let id {
            self.id = id
        }
        else {
            self.id = UUID()
        }
        if let url {
            self.url = url
        }
        if let movie {
            self.movie = movie
        }
    }
    
    // movie info operations
    var windowTitle: String {
        if let url = self.url {
            return url.lastPathComponent
        }
        return "New Movie"
    }
    
    // editing operations
    var isModified: Bool {
        return self.movie?.isModified ?? false
    }
    
    func selectAll() {
        self.selection = CMTimeRange(start: .zero, end: self.movie?.duration ?? .zero)
    }
    
    func select(_ selection: CMTimeRange) {
        self.selection = selection
    }
    
    func copy() {
        NSPasteboard.general.clearContents()
        
        if self.movie == nil {
            return
        }

        do {
            let movieHeader: Data = try self.movie!.makeMovieHeader(fileType: .mov)
            let result = NSPasteboard.general.setData(movieHeader, forType: qtMoviePasteboardType)
            print("\(result)")
        }
        catch {
            print("failed to makeMovieHeader: \(error) from movieID: \(self.id)")
        }
    }
    
    func addAsync() async {
        guard let movieHeader: Data = NSPasteboard.general.data(forType: qtMoviePasteboardType) else {
            return
        }
        
        guard let movie: AVMutableMovie = self.movie else {
            return
        }
        
        do {
            let movieToPaste = AVMovie(data: movieHeader)
            let tracksToPaste = try await movieToPaste.load(.tracks)
            let status = movieToPaste.status(of: .tracks)
            switch status {
            case .loaded:
                print("loaded value", movieToPaste.tracks)
            default:
                print("unexpected AVPlayerItemStatus: \(status)")
                return
            }
            for trackToPaste in tracksToPaste {
                let segmentsToInsert = try await trackToPaste.load(.segments)

                // create a matchingTrack in self.movie
                let track = movie.addMutableTrack(withMediaType: trackToPaste.mediaType, copySettingsFrom: trackToPaste)
                
                // walk the edits in trackToPaste, laying each edit (with data references, no actual data)
                // into that matchingTrack in self.movie
                for segment in segmentsToInsert {
                    try track?.insertTimeRange(segment.timeMapping.source, of: trackToPaste, at: .zero, copySampleData: false)
                }
            }
        }
        catch {
            print("error: \(error)")
        }
    }
}


class MovieStore {
    var movieInfos: [UUID:MovieInfo]
    init() {
        movieInfos = [:]
    }
    
    deinit {
        for id in movieInfos.keys {
            removeMovieInfo(for: id)
        }
    }
    
    // store manipulations
    func newMovie() -> MovieInfo {
        let id = UUID()
        return newMovie(for: id)
    }
    
    func newMovie(for id: UUID) -> MovieInfo {
        let info = MovieInfo(movie: AVMutableMovie(), id: id)
        movieInfos[id] = info
        return info
    }
    
    func getMovieInfo(for id: UUID) -> MovieInfo? {
        return movieInfos[id]
    }
    
    func openMovie(at url: URL) throws -> MovieInfo {
        do {
            _ = url.startAccessingSecurityScopedResource()
            let mov = try AVMutableMovie(url: url, error: ())
            let info = MovieInfo(movie: mov, url: url)
            movieInfos[info.id] = info
            return info
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
    
    func removeMovieInfo(for id: UUID) {
        if let info = movieInfos[id] {
            movieInfos.removeValue(forKey: id)
            if let url = info.url {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
        
    func contains(_ id: UUID) -> Bool {
        return movieInfos.keys.contains(id)
    }
}
