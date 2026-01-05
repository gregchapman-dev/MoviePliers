import SwiftUI
import AVFoundation
import CoreMedia
 
struct MoviePlayerControlsView: View {
    @Binding var viewModel: MovieViewModel
 
    var body: some View {
        VStack {
            // Video Player
            if let size = viewModel.size {
                MovieView(viewModel: $viewModel)
                    .frame(width:size.width, height:size.height)
            }
            else {
                MovieView(viewModel: $viewModel)
            }
            controlsView
        }
    }
 
    private var controlsView: some View {
        HStack(spacing: 8) {
            // Play/Pause Button
            Button(action: viewModel.togglePlayPause) {
                Image(viewModel.isPlaying ? "Pause" : "Play")
            }
            .frame(minWidth: 16, maxWidth: 16, minHeight: 16, maxHeight: 16, alignment: .center)
            .clipShape(Rectangle())
            
            // Timeline
            timelineView
                .frame(width: getSliderWidth(), alignment: .center)
        }
        .background(.clear)
        .frame(width: viewModel.size?.width)
    }
 
    private var timelineView: some View {
        VStack {
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
        //.padding(.horizontal)
    }
    
    func getSliderWidth() -> CGFloat {
        if let size = viewModel.size {
            return size.width - 24
        }
        return 640
    }
}
