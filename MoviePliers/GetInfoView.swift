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
    @Binding var viewModel: MovieViewModel
    @State var selectedTrackOrMovie: TrackInfo
    @State var selectedInfoView: InfoView

    var body: some View {
        VStack {
            HStack {
                Picker("", selection: $selectedTrackOrMovie) {
                    ForEach($viewModel.trackInfos, id: \.id) { trackInfo in
                        Text(trackInfo.name.wrappedValue)
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
                            Text(infoView.title)
                        }
                    }
                    else if selectedTrackOrMovie.track!.mediaType == .audio {
                        ForEach(audioTrackInfoViews, id: \.id) { infoView in
                            Text(infoView.title)
                        }
                    }
                    else if selectedTrackOrMovie.track!.mediaType == .video {
                        ForEach(videoTrackInfoViews, id: \.id) { infoView in
                            Text(infoView.title)
                        }
                    }
                    else {
                        ForEach(otherMediaTrackInfoViews, id: \.id) { infoView in
                            Text(infoView.title)
                        }
                    }
                }
            }

            Text("\(selectedTrackOrMovie.name): \(selectedInfoView.title)")
            Button("Dismiss") {
                viewModel.infoViewIsPresented = false // Dismiss the sheet
            }
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(minWidth: 400, minHeight: 300)
    }
}
