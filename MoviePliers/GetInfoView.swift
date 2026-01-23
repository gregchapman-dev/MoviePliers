import SwiftUI
import AVFoundation

struct InfoView: Identifiable, Hashable {
    let id: UUID = UUID()
    let title: String
}

let movieInfoViews: [InfoView] = [
    .init(title: "Annotations"),
    .init(title: "Colors"),
    .init(title: "Controller"),
    .init(title: "Files"),
    .init(title: "General"),
    .init(title: "Preview"),
    .init(title: "Size"),
    .init(title: "Time"),
]

let audioTrackInfoViews: [InfoView] = [
    .init(title: "Alternate"),
    .init(title: "Files"),
    .init(title: "Format"),
    .init(title: "General"),
    .init(title: "High Quality"),
    .init(title: "Preload"),
    .init(title: "Volume"),
]

let videoTrackInfoViews: [InfoView] = [
    .init(title: "Alternate"),
    .init(title: "Files"),
    .init(title: "Format"),
    .init(title: "Frame Rate"),
    .init(title: "Gamma"),
    .init(title: "General"),
    .init(title: "Graphics Mode"),
    .init(title: "High Quality"),
    .init(title: "Layer"),
    .init(title: "Mask"),
    .init(title: "Preload"),
    .init(title: "Size"),
]

let otherMediaTrackInfoViews: [InfoView] = [
    .init(title: "Alternate"),
    .init(title: "Files"),
    .init(title: "Format"),
    .init(title: "General"),
    .init(title: "High Quality"),
]

// This is for intercepting clicks on the red "close" bubble in the info window.
// We also call windowShouldClose by hand when File/Close (a.k.a. cmd-W) is performed.
class InfoWindowCloser: NSObject, NSWindowDelegate {
    let viewModel: MovieViewModel?

    init(for viewModel: MovieViewModel?) {
        self.viewModel = viewModel
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // always returns true; is only here so we can clear
        // state when closing.
        if let viewModel = self.viewModel {
            viewModel.infoWindow = nil
            if let originalInfoDelegate = viewModel.originalInfoDelegate {
                sender.delegate = originalInfoDelegate
                viewModel.myInfoDelegate = nil
                viewModel.originalInfoDelegate = nil
            }
        }
        return true
    }
}

struct GetInfoView: View {
    @State var viewModel: MovieViewModel
    @State var selectedInfoView: InfoView
    @State var selectedTrackOrMovie: TrackInfo

    init(movieID theID: UUID) {
        let vm = movieStore.getMovieViewModel(for: theID)
        if let vm {
            self.viewModel = vm
            //print("GetInfoView movie ID = \(theID)")
            self.selectedInfoView = movieInfoViews.first!
            self.selectedTrackOrMovie = vm.trackInfos.first!
        }
        else {
            // temporary; window is in the process of going away
            self.viewModel = MovieViewModel()
            self.selectedInfoView = movieInfoViews.first!
            self.selectedTrackOrMovie = TrackInfo(movie: AVMutableMovie())
        }
    }

    var body: some View {
        VStack {
            HStack {
                Picker("", selection: $selectedTrackOrMovie) {
                    ForEach($viewModel.trackInfos, id: \.id) { trackInfo in
                        Text(trackInfo.name.wrappedValue).tag(trackInfo.wrappedValue)
                    }
                }
                .onChange(of: selectedTrackOrMovie) { oldTrackInfo, newTrackInfo in
                    if newTrackInfo.track == nil {
                        selectedInfoView = movieInfoViews.first!
                    }
                    else if newTrackInfo.track!.mediaType == .audio {
                        selectedInfoView = audioTrackInfoViews.first!
                    }
                    else if newTrackInfo.track!.mediaType == .video {
                        selectedInfoView = videoTrackInfoViews.first!
                    }
                    else {
                        // for now all other track types have same info views.
                        selectedInfoView = otherMediaTrackInfoViews.first!
                    }
                }
                
                Picker("", selection: $selectedInfoView) {
                    if selectedTrackOrMovie.track == nil {
                        ForEach(movieInfoViews, id: \.id) { infoView in
                            Text(infoView.title).tag(infoView)
                        }
                    }
                    else if selectedTrackOrMovie.track!.mediaType == .audio {
                        ForEach(audioTrackInfoViews, id: \.id) { infoView in
                            Text(infoView.title).tag(infoView)
                        }
                    }
                    else if selectedTrackOrMovie.track!.mediaType == .video {
                        ForEach(videoTrackInfoViews, id: \.id) { infoView in
                            Text(infoView.title).tag(infoView)
                        }
                    }
                    else {
                        ForEach(otherMediaTrackInfoViews, id: \.id) { infoView in
                            Text(infoView.title).tag(infoView)
                        }
                    }
                }
            }
            Divider()
            infoDetailsView.frame(height: 300)
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(height: 300)
        .background(
            HostingWindowFinder { window in
                viewModel.infoWindow = window
                viewModel.originalInfoDelegate = window.delegate
                viewModel.myInfoDelegate = InfoWindowCloser(for: viewModel)
                // Setting window.delegate to our window closer, means that InfoWindowCloser.windowShouldClose()
                // will be called if the red bubble in the window is clicked.  Other close methods are handled
                // more directly in viewModel.closeView(), which is called from Close in the menu.
                window.delegate = viewModel.myInfoDelegate
            }
        )
        .onDisappear {
            viewModel.infoWindow = nil
        }
    }
    
    private var infoDetailsView: some View {
        ScrollView {
            if selectedTrackOrMovie.track == nil {
                // movie info views
                if selectedInfoView.title == "Annotations" {
                    movieAnnotationsView
                }
                else if selectedInfoView.title == "Colors" {
                    unimplementedView
                }
                else if selectedInfoView.title == "Controller" {
                    unimplementedView
                }
                else if selectedInfoView.title == "Files" {
                    unimplementedView
                }
                else if selectedInfoView.title == "General" {
                    unimplementedView
                }
                else if selectedInfoView.title == "Preview" {
                    unimplementedView
                }
                else if selectedInfoView.title == "Size" {
                    unimplementedView
                }
                else if selectedInfoView.title == "Time" {
                    movieTimeView
                }
                else {
                    unimplementedView
                }
            }
            else {
                // common track info views
                if selectedInfoView.title == "Format" {
                    if selectedTrackOrMovie.track!.mediaType == .audio {
                        audioTrackFormatView
                    }
                    else if selectedTrackOrMovie.track!.mediaType == .video {
                        videoTrackFormatView
                    }
                    else {
                        otherMediaTrackFormatView
                    }
                }
                else {
                    unimplementedView
                }
            }
        }
    }
    // Here are all the various things that can be displayed under the two pickers (based on which right-hand picker
    // is selected).
    
    private var movieAnnotationsView: some View {
        VStack {
            Text("Properties")
            ScrollView {
                Text("Single-select list of properties goes here")
                Text("Information")
                Text("Copyright")
            }.backgroundStyle(Color(.white))
            Text("Data")
            ScrollView {
                Text("Text value of property is displayed here")
            }.backgroundStyle(Color(.gray))
            HStack {
                Button("Add...") {
                    print("Add Property Button Pressed")
                }
                Button("Edit...") {
                    print("Edit Property Button Pressed")
                }
                Button("Delete") {
                    print("Delete Property Button Pressed")
                }
            }
        }
    }
    
    private var movieTimeView: some View {
        VStack {
            Text("Current Time: \(viewModel.currentTime.formatted(.withHMSMillisAndFraction))")
            Divider()
            Text("Duration: \(viewModel.duration.formatted(.withHMSMillisAndFraction))")
            Divider()
            if let selection = viewModel.selection {
                Text("Selection Start: \(selection.start.formatted(.withHMSMillisAndFraction))")
                Text("Selection End: \(selection.end.formatted(.withHMSMillisAndFraction))")
                Text("Selection Duration: \(selection.duration.formatted(.withHMSMillisAndFraction))")
            }
            else {
                Text("No selection")
            }
        }
    }

    private var audioTrackFormatView: some View {
        VStack {
            Text("Format: \(selectedTrackOrMovie.track!.audioFormat ?? "unknown")")
        }
    }
    
    private var videoTrackFormatView: some View {
        VStack {
            Text("Format: \(selectedTrackOrMovie.track!.videoCodecName ?? "unknown")")
        }
    }
    
    private var otherMediaTrackFormatView: some View {
        VStack {
            Text("Format: \(selectedTrackOrMovie.track!.mediaSubtypeName ?? "unknown")")
        }
    }
    
    private var unimplementedView: some View {
        Text("needs implementation: \(selectedTrackOrMovie.name) \(selectedInfoView.title)")
    }
}
