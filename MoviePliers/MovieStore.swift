import AppKit
import AVFoundation

let qtMoviePasteboardType = NSPasteboard.PasteboardType(rawValue: "com.apple.quicktime-movie")

class MovieStore {
    var movieViewModels: [UUID:MovieViewModel]
    init() {
        movieViewModels = [:]
    }
    
    deinit {
        for id in movieViewModels.keys {
            removeMovieViewModel(for: id)
        }
    }
    
    // store manipulations
    func newMovieViewModel() -> MovieViewModel {
        let id = UUID()
        return newMovieViewModel(for: id)
    }
    
    func newMovieViewModel(for id: UUID) -> MovieViewModel {
        let movie = AVMutableMovie()
        movie.timescale = 60000  // good enough for 59.94 fps (1001/60000 frame duration)
        let movieViewModel = MovieViewModel(movie: movie, id: id)
        movieViewModels[id] = movieViewModel
        return movieViewModel
    }
    
    func getMovieViewModel(for id: UUID) -> MovieViewModel? {
        return movieViewModels[id]
    }
    
    func openMovie(at url: URL) throws -> MovieViewModel {
        do {
            _ = url.startAccessingSecurityScopedResource()
            let mov = try AVMutableMovie(
                url: url,
                options: [
                    AVURLAssetPreferPreciseDurationAndTimingKey : true
                ],
                error: ()
            )
            let movieViewModel = MovieViewModel(movie: mov, url: url)
            movieViewModels[movieViewModel.id] = movieViewModel
            return movieViewModel
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
    
    func removeMovieViewModel(for id: UUID) {
        if let movieViewModel = movieViewModels[id] {
            movieViewModels.removeValue(forKey: id)
            if let url = movieViewModel.movieModel?.url {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
        
    func contains(_ id: UUID) -> Bool {
        return movieViewModels.keys.contains(id)
    }
}
