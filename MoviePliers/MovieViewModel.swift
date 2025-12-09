import AVFoundation
import AppKit

@Observable
class MovieViewModel: Identifiable {
    var id: UUID
    var movieModel: MovieModel?
    var selection: CMTimeRange?
    var interestingTimes: [CMTime]
    var isModified: Bool
    var showingDiscardDialog: Bool
    var window: NSWindow?
    var originalDelegate: NSWindowDelegate?
    var myDelegate: NSWindowDelegate?

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
        self.isModified = false
        self.showingDiscardDialog = false
        
        if let movie {
            self.movieModel = MovieModel(movie: movie, id: self.id, url: url, parent: self)
            self.duration = self.movieModel!.movie!.duration
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
    var duration: CMTime
    
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
    
    func movieDidChange(newCurrentTime: CMTime, newSelection: CMTimeRange?) {
        guard let player = self.player else { return }
        
        if let movie = self.movieModel?.movie {
            self.isModified = true
            let newPlayerItem = AVPlayerItem(asset: movie)
            player.replaceCurrentItem(with: newPlayerItem)
            // refresh some viewModel ideas from the modified movie
            self.duration = movie.duration
            self.selection = newSelection
            Task {
                await self.seek(to: newCurrentTime)
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

        // Run the panel modally
        let response = savePanel.runModal()

        if response == .OK {
            if let url = savePanel.url {
                self.saveAs(url, selfContained: false)
            }
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
            NSApplication.shared.keyWindow?.close()
            return
        }
        guard let closer = self.myDelegate else {
            // should never happen
            print("no delegate for viewModel, closing window")
            window.close()
            return
        }
        
        if closer.windowShouldClose!(window) {
            print("closing window for viewModel")
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
            await movieModel.add()
        }
    }
    
    func addScaled() {
        guard let movieModel = self.movieModel else { return }
        Task {
            // nil selection is ok, it means to scale to the entire movie duration
            await movieModel.addScaled(toTimeRange: self.selection)
        }
    }
    
    func replace() {
        // paste, replacing current selection time range
        guard let movieModel = self.movieModel, let selection = self.selection else { return }
        Task {
            // nil selection NOT OK, because we're supposed to paste at selection.start
            await movieModel.replace(selection)
        }
    }
    
    func clear() {
        guard let movieModel = self.movieModel, let selection = self.selection else { return }
        movieModel.clear(selection)
    }
    
    func trim() {
        guard let movieModel = self.movieModel, let selection = self.selection else {
            return
        }
        movieModel.trim(selection)
    }
    
    func runCursorTest() {
        guard let movieModel = self.movieModel else { return }
        Task {
            await movieModel.runCursorTest()
        }
    }
}
