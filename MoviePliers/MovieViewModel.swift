import SwiftUI
import CoreMedia
import AVFoundation
import AppKit

let _orderedMediaTypes: [AVMediaType] = [
    // These are in the order we would like to see them in the extract/delete/enable tracks dialogs
    .video, .audio, .haptic, .muxed,
    .text, .closedCaption, .subtitle,
    .timecode, .depthData, .metadata, .auxiliaryPicture
]

let _mediaTypeToName: [AVMediaType: String] = [
    .video: "Video",
    .audio: "Audio",
    .haptic: "Haptic",
    .muxed: "Muxed",
    .text: "Text",
    .closedCaption: "Closed Caption",
    .subtitle: "Subtitle",
    .timecode: "Timecode",
    .depthData: "Depth Data",
    .metadata: "Metadata",
    //.metadataObject: "Metadata Object",
    .auxiliaryPicture: "Auxiliary Picture",
]

class TrackInfo: Identifiable, Hashable {
    let id: UUID
    var name: String
    var enabled: Bool
    let track: AVMutableMovieTrack?
    let movie: AVMutableMovie?
    let duration: CMTime
    init(track: AVMutableMovieTrack? = nil, movie: AVMutableMovie) {
        self.id = UUID()
        if let track {
            var name: String = _mediaTypeToName[track.mediaType] ?? "Unknown"
            name += " Track"
            self.name = name
            self.track = track
            self.enabled = track.isEnabled
        } else {
            self.track = nil
            self.name = "Movie"
            self.enabled = true
        }
        self.movie = movie
        self.duration = movie.duration
    }
    static func == (lhs: TrackInfo, rhs: TrackInfo) -> Bool {
        return lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Observable
class MovieViewModel: Identifiable {
    var id: UUID
    var movieModel: MovieModel?
    var isLoaded: Bool
    var movieTimeScale: CMTimeScale?
    var currentTime: CMTime
    var duration: CMTime
    var selection: CMTimeRange?
    var interestingTimes: [CMTime]
    var isModified: Bool

    // includes first entry which actually is the movieInfo
    var trackInfos: [TrackInfo] = []

    // various sheets that can be presented:

    // extract/enable/delete tracks dialogs
    var extractTracksIsPresented: Bool = false
    var enableTracksIsPresented: Bool = false
    var deleteTracksIsPresented: Bool = false

    // Select... and Go To...
    var selectIsPresented: Bool = false
    var gotoTimeIsPresented: Bool = false

    var window: NSWindow?
    var originalDelegate: NSWindowDelegate?
    var myDelegate: NSWindowDelegate?

    var infoWindow: NSWindow?
    var originalInfoDelegate: NSWindowDelegate?
    var myInfoDelegate: NSWindowDelegate?

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
        self.duration = .zero
        self.isLoaded = false
        self.isModified = false

        if let movie {
            self.movieModel = MovieModel(movie: movie, id: self.id, url: url, parent: self)
            self.movieTimeScale = movie.timescale
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
            forInterval: CMTime(seconds: 0.5, preferredTimescale: self.movieTimeScale ?? 1000),
            queue: .main) { [weak self] time in
                if self?.player != nil {
                    // we only update time when we are enabled
                    if !self!.enablePeriodicTimeObserver {
                        return
                    }
                    if let movie = self?.movieModel?.movie {
                        var currTime = time.convertScale(movie.timescale, method: .roundHalfAwayFromZero)
                        if currTime.hasBeenRounded {
                            // ignore roundedness
                            currTime = CMTime(value: currTime.value, timescale: currTime.timescale)
                        }
                        self!.currentTime = currTime
                    }
                }
            }

        return self._player
    }

    func makeTrackInfos(from movieModel: MovieModel) -> [TrackInfo] {
        guard let movie = movieModel.movie else {
            return []
        }

        // First trackInfo is actually movieInfo
        let movieInfo = self.makeTrackInfo(from: nil, of: movie)

        // we group by mediaType (movieInfo goes first)
        var trackInfos: [TrackInfo] = [movieInfo]
        for mediaType in _orderedMediaTypes {
            let tracks = movie.tracks(withMediaType: mediaType)
            if !tracks.isEmpty {
                var infos: [TrackInfo] = []
                for track in tracks {
                    infos.append(self.makeTrackInfo(from: track, of: movie))
                }

                if infos.count > 1 {
                    // add numeric suffix for uniqueness
                    var index: Int = 1
                    for info in infos {
                        info.name += " \(index)"
                        index += 1
                    }
                }

                // append to result
                for info in infos {
                    trackInfos.append(info)
                }
            }
        }
        return trackInfos
    }

    func makeTrackInfo(from track: AVMutableMovieTrack?, of movie: AVMutableMovie) -> TrackInfo {
        return TrackInfo(track: track, movie: movie)
    }

    func trackInfosForIds(trackInfoIds: Set<UUID>) -> [TrackInfo] {
        var trackInfos: [TrackInfo] = []
        for trackInfo in self.trackInfos {
            if trackInfoIds.contains(trackInfo.id) {
                trackInfos.append(trackInfo)
            }
        }
        return trackInfos
    }

    var windowTitle: String {
        if let url = movieModel?.url {
            return url.lastPathComponent
        }
        return "New Movie"
    }

    var isPlaying: Bool {
        if let player = self.player {
            return player.timeControlStatus == .playing
        }
        return false
    }

    var size: CGSize? {
        return movieModel?.size
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

    func seek(to time: CMTime) async {
        if let player = self.player {
            self.enablePeriodicTimeObserver = false
            await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            self.currentTime = player.currentTime()
            self.enablePeriodicTimeObserver = true
        }
        else {
            self.currentTime = time
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
            let previousTime = try await getPreviousInterestingTime(before: self.currentTime)
            await self.seek(to: previousTime)
        }
    }

    func getNextSelectionOrMovieBoundaryTime(after currentTime: CMTime) -> CMTime {
        if self.selection == nil || self.selection!.isEmpty {
            return self.duration
        }
        if currentTime < self.selection!.start {
            return self.selection!.start
        }
        if currentTime < self.selection!.end {
            return self.selection!.end
        }
        return self.duration
    }

    func getPreviousSelectionOrMovieBoundaryTime(before currentTime: CMTime) -> CMTime {
        if self.selection == nil || self.selection!.isEmpty {
            return .zero
        }
        if currentTime > self.selection!.end {
            return self.selection!.end
        }
        if currentTime > self.selection!.start {
            return self.selection!.start
        }
        return .zero
    }

    func optionStepForward() async throws {
        if self.player != nil && self.playerItem != nil {
            let nextTime = getNextSelectionOrMovieBoundaryTime(after: self.currentTime)
            await self.seek(to: nextTime)
        }
    }

    func optionStepBackward() async throws {
        if self.player != nil && self.playerItem != nil {
            let previousTime = getPreviousSelectionOrMovieBoundaryTime(before: self.currentTime)
            await self.seek(to: previousTime)
        }
    }

    func movieDidLoad() {
        if let movieModel = self.movieModel, let movie = movieModel.movie {
            self.duration = movieModel.duration
            self.trackInfos = self.makeTrackInfos(from: movieModel)
            self.movieTimeScale = movie.timescale
            self.isLoaded = true
        }
    }

    func movieDidChange(newCurrentTime: CMTime = .invalid, newSelection: CMTimeRange? = .invalid) {
        guard let player = self.player else { return }

        if let movieModel = self.movieModel, let movie = movieModel.movie {
            self.isModified = true
            self.duration = movie.duration
            self.trackInfos = self.makeTrackInfos(from: movieModel)
            self.movieTimeScale = movie.timescale

            if let player = self.player {
                let newPlayerItem = AVPlayerItem(asset: movie)
                player.replaceCurrentItem(with: newPlayerItem)
            }

            if newSelection != .invalid {
                self.selection = newSelection
            }
            if newCurrentTime != .invalid {
                Task {
                    await self.seek(to: newCurrentTime)
                }
            }
        }
        else {
            player.replaceCurrentItem(with: nil)
            self.duration = .zero
            self.currentTime = .zero
        }
    }

    func showSaveAsPanel(suggestedFilename: String) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export"
        savePanel.prompt = "Save"
        savePanel.nameFieldStringValue = suggestedFilename
        savePanel.canCreateDirectories = true
        savePanel.allowedContentTypes = [.quickTimeMovie, .mpeg4Movie]

        // State for the accessory view
        var saveAsSelfContained: Bool = false
        let selectedOption = saveAsSelfContainedOptions[saveAsSelfContained ? 1 : 0]

        // Create the SwiftUI view and wrap it in a hosting controller
        let accessoryView = SavePanelAccessoryView(
            saveAsSelfContained: Binding(
                get: { saveAsSelfContained },
                set: { saveAsSelfContained = $0 }
            ),
            selectedOption: selectedOption
        )
        let hostingController = NSHostingController(rootView: accessoryView)

        // embed the SwiftUI in a custom view
        let customView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        customView.addSubview(hostingController.view)

        // use my own constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        // top and bottom clipped to custom view
        hostingController.view.topAnchor.constraint(equalTo: customView.topAnchor).isActive = true
        hostingController.view.bottomAnchor.constraint(equalTo: customView.bottomAnchor).isActive = true

        // leading and trailing spaces can stretch as far as they need to be, hence ≥0
        hostingController.view.leadingAnchor.constraint(greaterThanOrEqualTo: customView.leadingAnchor).isActive = true
        hostingController.view.trailingAnchor.constraint(greaterThanOrEqualTo: customView.trailingAnchor).isActive = true

        // center the SwiftUI view horizontal within custom view
        hostingController.view.centerXAnchor.constraint(equalTo: customView.centerXAnchor).isActive = true

        // usually fixed width and height
        // can be flexible when SwiftUI view is dynamic
        hostingController.view.widthAnchor.constraint(equalToConstant: customView.frame.width).isActive = true
        hostingController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: customView.frame.height).isActive = true

        savePanel.accessoryView = customView

        // Run the panel modally
        let response = savePanel.runModal()
        if response == .OK, let url = savePanel.url {
            self.saveAs(url, selfContained: saveAsSelfContained)
        }
    }

    func saveOrSaveAs() {
        if self.movieModel?.url == nil {
            self.showSaveAsPanel(suggestedFilename: "New Movie.mov")
        }
        else {
            // movie came from a file url; save by replacing the movie header there (deleting no other data)
            self.replaceMovieHeader()
        }
    }

    func closeView() {
        guard let window = self.window else {
            print("no window for viewModel, closing keywindow")
            self.player?.pause()
            movieStore.removeMovieViewModel(for: self.id)
            NSApplication.shared.keyWindow?.close()
            return
        }
        guard let closer = self.myDelegate else {
            // should never happen
            print("no delegate for viewModel, closing window")
            self.player?.pause()
            movieStore.removeMovieViewModel(for: self.id)
            window.close()
            return
        }

        if closer.windowShouldClose!(window) {
            print("closing window for viewModel")
            self.player?.pause()
            movieStore.removeMovieViewModel(for: self.id)

            // close associated info window (if open)
            if let infoWindow = self.infoWindow {
                if let infoCloser = self.myInfoDelegate, let windowShouldClose = infoCloser.windowShouldClose {
                    if windowShouldClose(infoWindow) {
                        infoWindow.close()
                    }
                }
                self.infoWindow = nil
                self.myInfoDelegate = nil
            }

            window.close()
        }
    }

    // editing functions
    func selectAll() {
        if self.duration == .zero {
            self.selection = nil
        }
        else {
            self.selection = CMTimeRange(start: .zero, end: self.duration)
        }
    }

    func select(_ selection: CMTimeRange) {
        if !selection.isValid || selection.isEmpty {
            self.selection = nil
        }
        else {
            self.selection = selection
        }
    }

    func selectNone() {
        self.selection = nil
    }

    func saveAs(_ url: URL, selfContained: Bool = false) {
        guard let movieModel = self.movieModel else { return }

        Task {
            await movieModel.saveAs(url, selfContained: selfContained)
            self.isModified = false
        }
    }

    func replaceMovieHeader() {
        guard let movieModel = self.movieModel else { return }

        Task {
            await movieModel.replaceMovieHeader()
            self.isModified = false
        }
    }

    // editing verbs (in edit menu)
    func copy() {
        guard let movieModel = self.movieModel, let selection = self.selection else { return }

        Task {
            await movieModel.copy(fromTimeRange: selection)
        }
    }

    func cut() {
        guard let movieModel = self.movieModel, let selection = self.selection else { return }

        Task {
            await movieModel.copy(fromTimeRange: selection, andClear: true)
        }
    }

    func paste() {
        guard let movieModel = self.movieModel else { return }

        Task {
            await movieModel.paste(at: self.currentTime)
        }
    }

    func add() {
        guard let movieModel = self.movieModel else { return }

        Task {
            await movieModel.add(at: self.currentTime)
        }
    }

    func addScaled() {
        // nil selection is ok, it means to scale to the entire movie duration
        guard let movieModel = self.movieModel else { return }
        Task {
            if self.selection == nil {
                await movieModel.addScaled()  // default params: at: .zero, scaledToDuration: movieModel.duration
            }
            else {
                await movieModel.addScaled(at: self.selection!.start, scaledToDuration: self.selection!.duration)
            }
        }
    }

    func replace() {
        // paste, replacing current selection time range
        // nil selection NOT OK, because we're supposed to paste at selection.start
        guard let movieModel = self.movieModel, let selection = self.selection else { return }
        Task {
            await movieModel.replace(selection)
        }
    }

    func clear() {
        // nil selection not ok (would be a no-op)
        guard let movieModel = self.movieModel, let selection = self.selection else { return }
        Task {
            await movieModel.clear(selection)
        }
    }

    func trim() {
        guard let movieModel = self.movieModel, let selection = self.selection else {
            return
        }
        Task {
            await movieModel.trim(selection)
        }
    }

    func addTrack(_ trackInfo: TrackInfo) {
        guard let movieModel = self.movieModel else { return }
        guard let track = trackInfo.track else { return }
        Task {
            await movieModel.addTrack(track, duration: trackInfo.duration)
        }
    }

    func deleteTrack(_ trackInfo: TrackInfo) {
        guard let movieModel = self.movieModel else { return }
        guard let track = trackInfo.track else { return }
        Task {
            await movieModel.deleteTrack(track)
        }
    }

    func toggleTrackEnabled(_ trackInfo: TrackInfo) {
        guard let movieModel = self.movieModel else { return }
        guard let track = trackInfo.track else { return }
        Task {
            await movieModel.toggleTrackEnabled(track)
        }
    }

    func runCursorTest() {
        guard let movieModel = self.movieModel else { return }
        Task {
            await movieModel.runCursorTest()
        }
    }
}
