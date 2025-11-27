import AVFoundation
import AppKit

@Observable
class MovieModel: Identifiable {
    // id has to be var (even though it is never set except in init) because we pass it around via focusedSceneValue
    var id: UUID
    
    // parent movieViewModel (so we can call it to say we modified the movie)
    var parent: MovieViewModel?
    
    var movie: AVMutableMovie?
    
    // url where the movie header is (either from file/open or from file/save/etc).
    // Doesn't exist for a new movie that has been edited, but not yet saved.
    var url: URL?
    
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
    
    func setParent(_ parentViewModel: MovieViewModel) {
        self.parent = parentViewModel
    }
    
    // editing operations
    var isModified: Bool {
        return self.movie?.isModified ?? false
    }
    
    func copy(fromTimeRange: CMTimeRange) async {
        guard let movie = self.movie else {
            return
        }

        do {
            // make new mutable movie that has all the same tracks (and eventually track relationships)
            // as self.movie, and for each newMovieTrack, insertTimeRange(selection, of: movieTrack,
            // at: .zero, copySampleData: false)
            let copiedMovie = AVMutableMovie()
            try copiedMovie.insertTimeRange(fromTimeRange, of: movie, at: .zero, copySampleData: false)
            let movieHeader: Data = try copiedMovie.makeMovieHeader(fileType: .mov)
            NSPasteboard.general.clearContents()
            let result = NSPasteboard.general.setData(movieHeader, forType: qtMoviePasteboardType)
            print("\(result)")
        }
        catch {
            print("copy failed: \(error) from movieID: \(self.id)")
        }
    }
    
    func add() async {
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
                print("unexpected movieToPaste.status: \(status)")
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
            // we apparently need to hand-notify the MovieViewModel, so it can make a new playerItem and put
            // it in the player.
            self.parent?.movieDidChange()
        }
        catch {
            print("error: \(error)")
        }
    }
}


