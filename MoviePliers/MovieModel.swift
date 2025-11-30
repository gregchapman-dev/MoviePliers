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
    
    var interestingTrackTimes: [CMTime]
    
    init(movie: AVMutableMovie? = nil, id: UUID? = nil, url: URL? = nil, parent: MovieViewModel? = nil) {
        if let id {
            self.id = id
        }
        else {
            self.id = UUID()
        }
        
        self.interestingTrackTimes = []
        
        if let url {
            self.url = url
        }
        if let parent {
            self.parent = parent
        }
        if let movie {
            self.movie = movie
            Task {
                await loadInterestingTimes()
            }
        }
    }
    
    func loadInterestingTimes() async {
        guard let movie = self.movie else {
            return
        }

        do {
            let tracks = try await movie.load(.tracks)
            for track in tracks {
                if track.mediaType == .video {
                    let segments = try await track.load(.segments)
                    for segment in segments {
                        // segment.timeMapping.source is media time range
                        let mediaTimeRange = segment.timeMapping.source
                        // segment.timeMapping.target is track time range
                        let trackTimeRange = segment.timeMapping.target

                        if let cursor = track.makeSampleCursor(presentationTimeStamp: trackTimeRange.start) {
                            while cursor.presentationTimeStamp < mediaTimeRange.end {
                                // walk the cursor through the media samples in this segment, noting the track times
                                // of each media sample as interesting times (we already got the first one).
                                let mediaTime = cursor.presentationTimeStamp
                                self.interestingTrackTimes.append(
                                    CMTimeMapTimeFromRangeToRange(
                                        mediaTime, fromRange: mediaTimeRange, toRange: trackTimeRange
                                    )
                                )
                                cursor.stepInPresentationOrder(byCount: 1)
                                if cursor.presentationTimeStamp == mediaTime {
                                    // cursor did not move; it refuses to step to exact end of movie
                                    // (because there isn't a sample that starts there), so assume
                                    // we're done, rather than loop forever.
                                    self.interestingTrackTimes.append(movie.duration)
                                    break
                                }
                            }
                        }
                    }
                    // we processed a video track, let's just be happy with that
                    break
                }
            }
        }
        catch {
            print("Error loading movie: \(error)")
        }
        if let parent = self.parent {
            parent.interestingTimesDidLoad()
        }
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

            // we have more tracks, we should re-load interesting times
            await loadInterestingTimes()
        }
        catch {
            print("error: \(error)")
        }
    }
}


