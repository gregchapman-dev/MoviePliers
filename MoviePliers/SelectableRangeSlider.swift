import SwiftUI
import CoreMedia
import AVFoundation

struct SelectableRangeSlider: View {
    @Bindable var viewModel: MovieViewModel
    @State private var shiftPressed: Bool
    @State private var optionPressed: Bool
    @FocusState private var focused: Bool
    
    let sliderHeight: CGFloat = 10
    let thumbHeight: CGFloat = 24
    let thumbWidth: CGFloat = 6
    let trackColor = Color.gray
    let selectionColor = Color.black
    let thumbColor = Color.white

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // The track
                Rectangle()
                    .fill(trackColor)
                    .frame(height: sliderHeight)
                    .cornerRadius(sliderHeight / 2)
                
                // The selected range visualization
                Rectangle()
                    .fill(selectionColor)
                    .frame(width: selectionWidth(geometry.size.width), height: sliderHeight)
                    .offset(x: selectionOffset(geometry.size.width))
                
                Text("currentValue=\(makeCMTimeString(viewModel.currentTime))")

                // The thumb
                Rectangle()
                    .fill(thumbColor)
                    .frame(width: thumbWidth, height: thumbHeight)
                    .cornerRadius(thumbHeight / 4)
                    .offset(x: convertTimeToThumbOffset(for: viewModel.currentTime, width: geometry.size.width))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDragOrTap(point: value.location, width: geometry.size.width)
                            }
                            .onEnded { value in
                                handleDragOrTap(point: value.location, width: geometry.size.width)
                            }
                    )
            }
            .contentShape(Rectangle()) // Makes the whole area tappable
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .onModifierKeysChanged(mask: [.shift, .option]) { _, newFlags in
                self.shiftPressed = newFlags.contains(.shift)
                self.optionPressed = newFlags.contains(.option)
            }
            .onKeyPress(keys: [.rightArrow]) { press in
                handleRightArrow()
                return .handled
            }
            .onKeyPress(keys: [.leftArrow]) { press in
                handleLeftArrow()
                return .handled
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragOrTap(point: value.location, width: geometry.size.width)
                    }
                    .onEnded { value in
                        handleDragOrTap(point: value.location, width: geometry.size.width)
                    }
            )
            .onAppear {
                focused = true
            }            
        }
        .frame(height: sliderHeight)
    }
    
    init(viewModel: MovieViewModel) {
        self.viewModel = viewModel
        self.shiftPressed = false
        self.optionPressed = false
    }
    
    // Convert tap point to a slider value
    func convertValue(for point: CGPoint, width: CGFloat) -> CMTime {
        if point.x < 0.0 { return .zero }
        let percentage = Double(point.x / width)
        if percentage > 1.0 { return viewModel.duration }
        let cgFloatTime = viewModel.duration.seconds * percentage
        return CMTimeMakeWithSeconds(cgFloatTime, preferredTimescale: viewModel.movieModel!.movie!.timescale)
    }
    
    // Convert slider value to thumb x coordinate
    func convertTimeToThumbOffset(for time: CMTime, width: CGFloat) -> CGFloat {
        let percentage: CGFloat = CGFloat(time.seconds / viewModel.duration.seconds)
        return (width * percentage)
    }
    
    func handleDragOrTap(point: CGPoint, width: CGFloat) {
        Task {
            let newMovieTime = convertValue(for: point, width: width)
            let oldMovieTime = viewModel.currentTime
            await viewModel.seek(to: newMovieTime)
            handleSelection(oldTime: oldMovieTime, newTime: newMovieTime, clearIfUnshifted: true)
        }
    }
    
    func handleSelection(oldTime: CMTime, newTime: CMTime, clearIfUnshifted: Bool = false) {
        if self.shiftPressed {
            // modify selection
            if viewModel.selection == nil || viewModel.selection!.isEmpty {
                // no current selection, set the selection to oldTime..newTime
                if oldTime == newTime {
                    viewModel.selection = nil
                }
                else {
                    // get the start/end in the right order
                    let lowerTime: CMTime = min(oldTime, newTime)
                    let higherTime: CMTime = max(oldTime, newTime)
                    viewModel.selection = CMTimeRange(start: lowerTime, end: higherTime)
                }
            }
            else {
                // there is an existing selection, so we need to modify it
                // (we ignore oldTime in all these cases)
                if newTime > viewModel.selection!.end {
                    if viewModel.selection!.start == newTime {
                        viewModel.selection = nil
                    }
                    else {
                        viewModel.selection = CMTimeRange(start: viewModel.selection!.start, end: newTime)
                    }
                }
                else if newTime < viewModel.selection!.start {
                    if newTime == viewModel.selection!.end {
                        viewModel.selection = nil
                    }
                    else {
                        viewModel.selection = CMTimeRange(start: newTime, end: viewModel.selection!.end)
                    }
                }
                else {
                    // newMovieTime is inside the current selection
                    // figure out which end is closest, and move that one
                    let endIsCloser = viewModel.selection!.end - newTime < newTime - viewModel.selection!.start
                    if endIsCloser {
                        viewModel.selection = CMTimeRange(start: viewModel.selection!.start, end: newTime)
                    } else {
                        viewModel.selection = CMTimeRange(start: newTime, end: viewModel.selection!.end)
                    }
                }
            }
        }
        else {
            if clearIfUnshifted {
                // Regular click: clear selection
                viewModel.selection = nil
            }
        }
    }
    
    func handleRightArrow() {
        Task {
            let oldMovieTime = viewModel.currentTime
            if self.optionPressed {
                try await viewModel.optionStepForward()
            }
            else {
                try await viewModel.stepForward()
            }
            let newMovieTime = viewModel.currentTime
            handleSelection(oldTime: oldMovieTime, newTime: newMovieTime)
        }
    }
    
    func handleLeftArrow() {
        Task {
            let oldMovieTime = viewModel.currentTime
            if self.optionPressed {
                try await viewModel.optionStepBackward()
            }
            else {
                try await viewModel.stepBackward()
            }
            let newMovieTime = viewModel.currentTime
            handleSelection(oldTime: oldMovieTime, newTime: newMovieTime)
        }
    }
    
    // Helper to calculate the visual width of the selected range
    func selectionWidth( _ width: CGFloat) -> CGFloat {
        let totalRange = viewModel.duration.seconds
        let selectedRange = viewModel.selection?.duration.seconds ?? 0.0
        let output = CGFloat(selectedRange / totalRange) * width
        return output
    }
    
    // Helper to calculate the visual offset of the selected range
    func selectionOffset( _ width: CGFloat) -> CGFloat {
        let totalRange = viewModel.duration.seconds
        let offsetFromStart = viewModel.selection?.start.seconds ?? 0.0
        let output = CGFloat(offsetFromStart / totalRange) * width
        return output
    }
    
    func makeCMTimeString(_ time: CMTime) -> String {
        return "\(time.value)/\(time.timescale)"
    }
}
