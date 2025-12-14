import SwiftUI
import AVFoundation

struct InfoView: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
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

struct GetInfoView: View {
    @State var viewModel: MovieViewModel
    @State var selectedInfoView: InfoView
    @State var selectedTrackOrMovie: TrackInfo

    init(movieID theID: UUID) {
        let vm = movieStore.getMovieViewModel(for: theID)!
        self.viewModel = vm
        print("GetInfoView movie ID = \(theID)")
        self.selectedInfoView = movieInfoViews.first!
        self.selectedTrackOrMovie = vm.trackInfos.first!
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

            infoDetailsView.frame(width: 300, height: 300)
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(width: 300, height: 300)
    }
    
    private var infoDetailsView: some View {
        ScrollView {
            if selectedInfoView.title == "Annotations" {
                movieAnnotationsView
            }
//            else if selectedInfoView.title == "Time" {
//                movieTimeView
//            }
            else {
                Text("needs implementation: \(selectedTrackOrMovie.name)\(selectedInfoView.title)")
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

}
