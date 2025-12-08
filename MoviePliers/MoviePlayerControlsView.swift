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
        .confirmationDialog("Discard changes?", isPresented: $viewModel.showingDiscardDialog) {
            Button("Discard Changes", role: .destructive) {
                print("removed, closing window")
                print("viewModel.window: \(String(describing: viewModel.window))")
                viewModel.window?.close()
                viewModel.showingDiscardDialog = false
                movieStore.removeMovieViewModel(for: viewModel.id)
            }
            // SwiftUI automatically adds a standard cancel button if no other .cancel role button is provided
            Button("Cancel", role: .cancel) {
                print("cancelled")
                print("viewModel.isModified: \(viewModel.isModified)")
                viewModel.showingDiscardDialog = false
            }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
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
                viewModel: viewModel
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
  
    private func formatTime(_ time: CMTime) -> String {
        let timeInSeconds = time.seconds
        guard !timeInSeconds.isNaN && !timeInSeconds.isInfinite else {
            return "0:00"
        }
 
        let hours = Int(timeInSeconds) / 3600
        let minutes = (Int(timeInSeconds) / 60) - (hours * 60)
        let seconds = Int(timeInSeconds) % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
}
