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
    
    init(movie: AVMutableMovie? = nil, id: UUID? = nil, url: URL? = nil, parent: MovieViewModel? = nil) {
        if let id {
            self.id = id
        }
        else {
            self.id = UUID()
        }
        
        if let url {
            self.url = url
        }
        if let parent {
            self.parent = parent
        }
        if let movie {
            self.movie = movie
        }
    }
        
    // editing operations
    var isModified: Bool {
        return self.movie?.isModified ?? false
    }
    
    func fileType(for url: URL) -> AVFileType? {
        // returns nil if url.pathExtension doesn't map to a fileType
        if url.pathExtension == "mov" {
            return .mov
        }
        if url.pathExtension == "mp4" {
            return .mp4
        }
        return nil
    }
    
    func saveAs(_ url: URL, selfContained: Bool = false) async {
        guard let movie = self.movie else {
            return
        }
        
        var theURL: URL = url
        var fileType: AVFileType? = fileType(for: theURL)
        if fileType == nil {
            // add .mov extension and save as .mov
            theURL = url.appendingPathExtension("mov")
            fileType = .mov
        }
        
        do {
            if selfContained {
                print("self-contained write not yet implemented, writing header only")
            }
            try movie.writeHeader(to: theURL, fileType: fileType!, options: .truncateDestinationToMovieHeaderOnly)
            self.url = theURL
        }
        catch {
            print("error saving movie: \(error.localizedDescription)")
        }
    }
    
    func replaceMovieHeader() async {
        guard let movie = self.movie else {
            return
        }
        guard let url = self.url else {
            return
        }
        do {
            let fileType = fileType(for: url)
            
            if let fileType {
                try movie.writeHeader(to: url, fileType: fileType, options: .addMovieHeaderToDestination)
//                let newMovieHeader: Data = try movie.makeMovieHeader(fileType: fileType)
//                // scan the file at url for 'moov'
//                let atomParser = AtomParser(url)
//                atomParser.replaceMoovAtom(with: newMovieHeader)
            }
            else {
                print("cannot save movie header to \(url.pathExtension) file")
                return
            }
        }
        catch {
            print("error saving movie: \(error.localizedDescription)")
        }
    }
    
    func copy(fromTimeRange: CMTimeRange) async {
        guard let movie = self.movie else {
            return
        }

        do {
            // make new mutable movie that has all the same tracks (and eventually track relationships)
            // as self.movie, and for each newMovieTrack, insertTimeRange(selection, of: movieTrack,
            // at: .zero, copySampleData: false)
//            let copiedMovie = AVMutableMovie()
//            try copiedMovie.insertTimeRange(fromTimeRange, of: movie, at: .zero, copySampleData: false)
//            let movieHeader: Data = try copiedMovie.makeMovieHeader(fileType: .mov)
//            NSPasteboard.general.clearContents()
//            let result = NSPasteboard.general.setData(movieHeader, forType: qtMoviePasteboardType)
//            print("\(result)")
            let tracksToCopy = try await movie.load(.tracks)
            let status = movie.status(of: .tracks)
            switch status {
            case .loaded:
                let _ = 1
                //print("loaded value", movie.tracks)
            default:
                print("unexpected movie.status: \(status)")
                return
            }
            let copiedMovie = AVMutableMovie()
            copiedMovie.timescale = movie.timescale
            for trackToCopy in tracksToCopy {
                // create a matchingTrack in self.movie
                if let track = copiedMovie.addMutableTrack(withMediaType: trackToCopy.mediaType, copySettingsFrom: trackToCopy) {
                    // copy the selected time range into that track (just the references, ma'am)
                    try track.insertTimeRange(fromTimeRange, of: trackToCopy, at: .zero, copySampleData: false)
                }
            }
            let movieHeader: Data = try copiedMovie.makeMovieHeader(fileType: .mov)
            NSPasteboard.general.clearContents()
            let result = NSPasteboard.general.setData(movieHeader, forType: qtMoviePasteboardType)
            if result {
                print("copy: succeeded")
            }
            else {
                print("copy: failed")
            }
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
            let duration = try await movieToPaste.load(.duration)
            let status = movieToPaste.status(of: .tracks)
            switch status {
            case .loaded:
                print("loaded value", movieToPaste.tracks)
            default:
                print("unexpected movieToPaste.status: \(status)")
                return
            }
            for trackToPaste in tracksToPaste {
                // create a matchingTrack in self.movie
                if let track = movie.addMutableTrack(withMediaType: trackToPaste.mediaType, copySettingsFrom: trackToPaste) {
                    try track.insertTimeRange(CMTimeRange(start: .zero, end: duration), of: trackToPaste, at: .zero, copySampleData: false)
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
    
    func paste(at time: CMTime) async {
        guard let movieHeader: Data = NSPasteboard.general.data(forType: qtMoviePasteboardType) else {
            return
        }
        
        guard let movie: AVMutableMovie = self.movie else {
            return
        }
        
        do {
            let movieToPaste = AVMovie(data: movieHeader)
            let tracksToPaste = try await movieToPaste.load(.tracks)
            let duration = try await movieToPaste.load(.duration)
            let status = movieToPaste.status(of: .tracks)
            switch status {
            case .loaded:
                print("loaded value", movieToPaste.tracks)
            default:
                print("unexpected movieToPaste.status: \(status)")
                return
            }
            for trackToPaste in tracksToPaste {
                // find first matchingTrack in self.movie
                var matchingTrack: AVMutableMovieTrack? = nil
                let matchingTracks = movie.tracks(withMediaType: trackToPaste.mediaType)
                if matchingTracks.count > 0 {
                    matchingTrack = matchingTracks[0]
                }
                else {
                    matchingTrack = movie.addMutableTrack(withMediaType: trackToPaste.mediaType, copySettingsFrom: trackToPaste)
                }
                if let matchingTrack {
                    try matchingTrack.insertTimeRange(CMTimeRange(start: .zero, end: duration), of: trackToPaste, at: time, copySampleData: false)
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
    
    func runCursorTest() async {
        guard let movie: AVMutableMovie = self.movie else { return }
        
        var currentTime = CMTime.zero
        var nextCurrentTime = CMTime.zero
        let cursor = movie.tracks(withMediaType: .video)[0].makeSampleCursor(presentationTimeStamp: .zero)
        while nextCurrentTime < movie.duration {
            currentTime = nextCurrentTime
            cursor!.stepInPresentationOrder(byCount: 1)
            nextCurrentTime = cursor!.presentationTimeStamp
            if nextCurrentTime - currentTime != CMTime(value: 1001, timescale: 30000) {
                print("hey")
            }
        }
    }
}


