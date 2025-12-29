import SwiftUI
import CoreMedia
 
struct MoviePlayerControlsView: View {
    @Binding var viewModel: MovieViewModel
 
    var body: some View {
        VStack {
            // Video Player
            MovieView(viewModel: $viewModel)
            controlsView
        }
    }
 
    private var controlsView: some View {
        HStack {
            // Play/Pause Button
            Button(action: viewModel.togglePlayPause) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
            }
            
            // Timeline
            timelineView
        }
        .background(
            .clear
//            LinearGradient(
//                colors: [.clear, .black.opacity(0.7)],
//                startPoint: .top,
//                endPoint: .bottom
//            )
        )
    }
 
    private var timelineView: some View {
        VStack(spacing: 8) {
            // Progress Slider
            SelectableRangeSlider(
                viewModel: viewModel
            )
            .tint(.white)
 
            // Time Labels
            HStack {
                Text(viewModel.currentTime.formatted())
                    .font(.caption)
                    .foregroundColor(.black)
 
                Spacer()
 
                Text(viewModel.duration.formatted())
                    .font(.caption)
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal)
    }
}
