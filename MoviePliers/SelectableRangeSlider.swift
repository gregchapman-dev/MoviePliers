import SwiftUI
import CoreMedia

struct SelectableRangeSlider: View {
    @Bindable var viewModel: MovieViewModel
    @State private var selectionStart: CMTime
    @State private var selectionEnd: CMTime
    @State private var shiftPressed: Bool
    @FocusState private var focused: Bool
    
    let sliderHeight: CGFloat = 10
    let thumbHeight: CGFloat = 24
    let thumbWidth: CGFloat = 16
    let trackColor = Color.gray
    let selectionColor = Color.black
    let thumbColor = Color.purple
    let stepValue = 0.1

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
                
                Text("currentValue=\(makeCMTimeString(self.viewModel.currentTime))")

                // The thumb
                Rectangle()
                    .fill(thumbColor)
                    .frame(width: thumbWidth, height: thumbHeight)
                    .cornerRadius(thumbHeight / 4)
                    .position(x: 0, y: sliderHeight)
                    .offset(x: convertTimeToThumbOffset(for: self.viewModel.currentTime, width: geometry.size.width))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleDrag(point: value.location, width: geometry.size.width)
                            }
                            .onEnded { value in
                                handleDrag(point: value.location, width: geometry.size.width)
                            }
                        )
            }
            .contentShape(Rectangle()) // Makes the whole area tappable
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .onModifierKeysChanged(mask: .shift) { _, newFlags in
                if newFlags.contains(.shift) {
                    self.shiftPressed = true
                }
                else {
                    self.shiftPressed = false
                }
            }
            .onKeyPress(keys: [.rightArrow]) { press in
                handleRightArrow()
                return .handled
            }
            .onKeyPress(keys: [.leftArrow]) { press in
                handleLeftArrow()
                return .handled
            }
            .onTapGesture { point in
                handleTap(point: point, width: geometry.size.width)
            }
            .onAppear {
                focused = true
            }            
        }
        .frame(height: sliderHeight)
    }
    
    init(viewModel: MovieViewModel) {
        self.viewModel = viewModel
        self.selectionStart = .zero
        self.selectionEnd = .zero
        self.shiftPressed = false
    }
    
    // Convert tap point to a slider value
    func convertValue(for point: CGPoint, width: CGFloat) -> CMTime {
        let percentage = Double(point.x / width)
        let cgFloatTime = viewModel.duration.seconds * percentage
        return CMTimeMakeWithSeconds(cgFloatTime, preferredTimescale: Int32(NSEC_PER_SEC))
    }
    
    // Convert slider value to thumb x coordinate
    func convertTimeToThumbOffset(for time: CMTime, width: CGFloat) -> CGFloat {
        let percentage: CGFloat = CGFloat(time.seconds / viewModel.duration.seconds)
        return (width * percentage)
    }
    
    func handleTap(point: CGPoint, width: CGFloat) {
        let newMovieTime = convertValue(for: point, width: width)
        self.viewModel.seek(to: newMovieTime)
        handleSelection(newMovieTime)
    }
    
    func handleDrag(point: CGPoint, width: CGFloat) {
        let newMovieTime = convertValue(for: point, width: width)
        self.viewModel.seek(to: newMovieTime)
        handleSelection(newMovieTime)
    }
    
    func handleSelection(_ newMovieTime: CMTime) {
        if self.shiftPressed {
            // modify selection
            if self.selectionStart == self.selectionEnd {
                self.selectionStart = min(self.selectionStart, newMovieTime)
                self.selectionEnd = max(self.selectionEnd, newMovieTime)
            }
            else if newMovieTime > self.selectionEnd {
                self.selectionEnd = newMovieTime
            }
            else if newMovieTime < self.selectionStart {
                self.selectionStart = newMovieTime
            }
            else {
                // newMovieTime is inside the current selection
                // figure out which end is closest, and move that one
                let endIsCloser = self.selectionEnd - newMovieTime < newMovieTime - self.selectionStart
                if endIsCloser {
                    self.selectionEnd = newMovieTime
                } else {
                    self.selectionStart = newMovieTime
                }
                
            }
        } else {
            // Regular click: Set a single point (or the start of a new range)
            self.selectionStart = newMovieTime
            self.selectionEnd = newMovieTime
        }
    }
    
    func handleRightArrow() {
        self.viewModel.stepForward()
        let newMovieTime = self.viewModel.currentTime
        handleSelection(newMovieTime)
    }
    
    func handleLeftArrow() {
        self.viewModel.stepBackward()
        let newMovieTime = self.viewModel.currentTime
        handleSelection(newMovieTime)
    }
    
    // Helper to calculate the visual width of the selected range
    func selectionWidth( _ width: CGFloat) -> CGFloat {
        let totalRange = self.viewModel.duration.seconds
        let selectedRange = self.selectionEnd.seconds - self.selectionStart.seconds
        let output = CGFloat(selectedRange / totalRange) * width
        return output
    }
    
    // Helper to calculate the visual offset of the selected range
    func selectionOffset( _ width: CGFloat) -> CGFloat {
        let totalRange = self.viewModel.duration.seconds
        let offsetFromStart = self.selectionStart.seconds
        let output = CGFloat(offsetFromStart / totalRange) * width
        return output
    }
    
    func makeCMTimeString(_ time: CMTime) -> String {
        return "\(time.value)/\(time.timescale)"
    }
}
