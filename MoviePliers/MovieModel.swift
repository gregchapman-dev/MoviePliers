import AVFoundation
import AppKit

@Observable
class MovieModel: Identifiable {
    // id has to be var (even though it is never set except in init) because we pass it around via focusedSceneValue
    var id: UUID
    
    // parent movieViewModel (so we can call it to say we modified the movie)
    var parent: MovieViewModel?
    
    var movie: AVMutableMovie?
    var duration: CMTime = .zero
    var tracks: [AVMutableMovieTrack] = []
    
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
            Task {
                await self.reloadMovie()
                parent?.movieDidLoad()
            }
        }
    }
    
    func reloadMovie() async {
        guard let movie = self.movie else {
            return
        }
        
        do { self.duration = try await movie.load(.duration) }
        catch { self.duration = .zero }
        
        do { self.tracks = try await movie.load(.tracks) }
        catch { self.tracks = [] }
    }
    
    func movieDidChange(newCurrentTime: CMTime = .invalid, newSelection: CMTimeRange? = .invalid) async {
        // .invalid means do not change current time (or the current selection)
        await self.reloadMovie()
        self.parent?.movieDidChange(newCurrentTime: newCurrentTime, newSelection: newSelection)
    }
        
    // saving operations
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
        
        guard let fileType else {
            return
        }
        
        do {
            if selfContained {
                let savedMovie = try AVMutableMovie(settingsFrom: movie)
                savedMovie.timescale = movie.timescale
                let mediaDataStorage = AVMediaDataStorage(url: theURL)
                savedMovie.defaultMediaDataStorage = mediaDataStorage
                try savedMovie.insertTimeRange(CMTimeRange(start: .zero, end: movie.duration), of: movie, at: .zero, copySampleData: true)
                try savedMovie.writeHeader(to: theURL, fileType: fileType, options: .addMovieHeaderToDestination)
                // update movieModel to be the savedMovie
                self.movie = savedMovie
                self.url = theURL
                await self.movieDidChange()
            }
            else {
                try movie.writeHeader(to: theURL, fileType: fileType, options: .truncateDestinationToMovieHeaderOnly)
                self.url = theURL
            }
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
    
    // editing operations
    func copy(fromTimeRange: CMTimeRange, andClear: Bool = false) async {
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
                if andClear {
                    _delete(timeRange: fromTimeRange, from: movie)
                }
            }
            else {
                print("copy: failed")
            }
        }
        catch {
            print("copy failed: \(error) from movieID: \(self.id)")
        }
    }

    func add(at: CMTime, scaledToDuration: CMTime? = nil) async {
        // scaledToDuration == nil means just do an add.  addScaled() will never pass nil.
        guard let movieHeader: Data = NSPasteboard.general.data(forType: qtMoviePasteboardType) else {
            return
        }
        
        guard let movie: AVMutableMovie = self.movie else {
            return
        }
        
        do {
            let movieToPaste = AVMovie(data: movieHeader)
            let tracksToPaste = try await movieToPaste.load(.tracks)
            var pastedDuration = try await movieToPaste.load(.duration)
            if tracksToPaste.count == 0 {
                return
            }
            if !pastedDuration.isNumeric {
                return
            }

            for trackToPaste in tracksToPaste {
                // create a matchingTrack in self.movie
                if let track = movie.addMutableTrack(withMediaType: trackToPaste.mediaType, copySettingsFrom: trackToPaste) {
                    try track.insertTimeRange(
                        CMTimeRange(start: .zero, end: pastedDuration), 
                        of: trackToPaste, 
                        at: at, 
                        copySampleData: false
                    )
                    if let scaledToDuration {
                        track.scaleTimeRange(
                            CMTimeRange(start: .zero, end: pastedDuration),
                            toDuration: scaledToDuration)
                        pastedDuration = scaledToDuration
                    }
                }
            }

            // New selection is the added timerange, and new thumb position is at the end of the add
            let newSelection = CMTimeRange(start: at, duration: pastedDuration)
            await self.movieDidChange(newCurrentTime: newSelection.end, newSelection: newSelection)
            
            return
        }
        catch {
            print("error: \(error)")
        }
        
        return
    }
    
    func addScaled(at: CMTime? = nil, scaledToDuration: CMTime? = nil) async {
        guard let movie: AVMutableMovie = self.movie else {
            return
        }
        
        // both params must be non-nil, or both must be nil
        if (at == nil) != (scaledToDuration == nil) {
            return
        }
        
        // if selection (i.e. both at and scaledToDuration) is nil, addScaled scales to the movie duration
        // (Stern & Lettieri, p. 77)
        var atTime: CMTime
        if at == nil {
            atTime = .zero
        }
        else {
            atTime = at!
        }
        
        var duration = scaledToDuration
        if duration == nil {
            duration = try? await movie.load(.duration)
        }
        
        if let duration {
            await add(at: atTime, scaledToDuration: duration)
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
            let duration: CMTime = try await movieToPaste.load(.duration)
            if tracksToPaste.count == 0 {
                return
            }
            if !duration.isNumeric {
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
                    try matchingTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: trackToPaste,
                        at: time,
                        copySampleData: false
                    )
                }
            }
                        
            // we apparently need to hand-notify the MovieViewModel, so it can make a new playerItem and put
            // it in the player.
            // New selection is the pasted timerange, and new thumb position is at the end of the paste
            let newSelection = CMTimeRange(start: time, duration: duration)
            await self.movieDidChange(newCurrentTime: newSelection.end, newSelection: newSelection)
        }
        catch {
            print("error: \(error)")
        }
        
        return
    }
    
    func replace(_ selection: CMTimeRange) async {
        // first clear selection, then paste at selection.start
        guard let movie: AVMutableMovie = self.movie else { return }
        _delete(timeRange: selection, from: movie)
        await paste(at: selection.start)
    }
    
    func clear(_ selection: CMTimeRange) async {
        // returns true if anything was deleted
        guard let movie: AVMutableMovie = self.movie else { return }
        _delete(timeRange: selection, from: movie)
        // New selection is nil (we cleared it), and new thumb position is where the old selection started
        // (which is now the frame just after the cleared area).
        await self.movieDidChange(newCurrentTime: selection.start, newSelection: nil)
    }
    
    func trim(_ selection: CMTimeRange) async {
        // returns true if anything was deleted
        guard let movie: AVMutableMovie = self.movie else { return }
        let origDuration: CMTime? = try? await movie.load(.duration)
        if let origDuration {
            // delete tail first, because once we delete head, tail will move
            let tailTimeRange = CMTimeRange(start: selection.end, duration: origDuration)
            _delete(timeRange: tailTimeRange, from: movie)
            
            let headTimeRange = CMTimeRange(start: .zero, end: selection.start)
            _delete(timeRange: headTimeRange, from: movie)
            
            await self.movieDidChange(
                newCurrentTime: selection.duration,
                newSelection: CMTimeRange(start: .zero, duration:  selection.duration)
            )
        }
    }
    
    func _delete(timeRange: CMTimeRange, from theMovie: AVMutableMovie) {
        theMovie.removeTimeRange(timeRange)
    }
    
    // track operations
    func addTrack(_ trackToAdd: AVMutableMovieTrack, duration: CMTime) async {
        guard let movie: AVMutableMovie = self.movie else { return }

        if let track = movie.addMutableTrack(withMediaType: trackToAdd.mediaType, copySettingsFrom: trackToAdd) {
            try? track.insertTimeRange(
                CMTimeRange(start: .zero, end: duration),
                of: trackToAdd,
                at: .zero,
                copySampleData: false
            )
            // after adding a track (e.g. during extract track operations) the result should
            // not have any selection, and should be positioned at .zero, like you just opened
            // this movie.
            await self.movieDidChange(newCurrentTime: .zero, newSelection: nil)
        }
    }
    
    func deleteTrack(_ track: AVMutableMovieTrack) async {
        guard let movie: AVMutableMovie = self.movie else { return }
        movie.removeTrack(track)
        await self.movieDidChange()
    }
    
    func toggleTrackEnabled(_ track: AVMutableMovieTrack) async {
        track.isEnabled.toggle()
        await self.movieDidChange()
    }
    
    func runCursorTest() async {
        guard let movie: AVMutableMovie = self.movie else { return }
        
        var currentTime: CMTime
        var nextCurrentTime = CMTime(value: 2067065, timescale: 30000)
        let cursor = await movie.tracks(withMediaType: .video)[0].makeTrackSampleCursor(presentationTimeStamp: nextCurrentTime)
        while nextCurrentTime < movie.duration {
            if nextCurrentTime == CMTime(value: 6164872, timescale: 60000) {
                print("hay")
            }
            currentTime = nextCurrentTime
            cursor.stepInPresentationOrder(byCount: 1)
            nextCurrentTime = cursor.presentationTimeStamp
            //let storageRange = cursor!.currentSampleStorageRange
            if nextCurrentTime - currentTime != CMTime(value: 1001, timescale: 30000) {
                print("partial frame start: \(currentTime) end: \(nextCurrentTime) dur: \(nextCurrentTime - currentTime)")
            }
        }
    }
}


