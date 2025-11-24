import SwiftUI
 
struct MoviePlayerControlsView: View {
    @Binding var viewModel: MovieViewModel
    @State var modifierKeyMonitor: ModifierKeyMonitor = ModifierKeyMonitor()
    @State private var isShowingControls = true
 
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
                    .foregroundColor(.black)
            }
            
            // Timeline
            timelineView
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
 
    private var timelineView: some View {
        VStack(spacing: 8) {
            // Progress Slider
            SelectableRangeSlider(
                viewModel: viewModel,
                modifierKeyMonitor: modifierKeyMonitor
            )
            .tint(.white)
 
            // Time Labels
            HStack {
                Text(formatTime(viewModel.currentTime))
                    .font(.caption)
                    .foregroundColor(.white)
 
                Spacer()
 
                Text(formatTime(viewModel.duration))
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
    }
  
    // MARK: - Helper Methods
  
    private func formatTime(_ timeInSeconds: Double) -> String {
        guard !timeInSeconds.isNaN && !timeInSeconds.isInfinite else {
            return "0:00"
        }
 
        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
