import SwiftUI

struct SelectableRangeSlider: View {
    @Bindable var viewModel: MovieViewModel
    @State private var selectionStart: Double
    @State private var selectionEnd: Double
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
                
                Text("currentValue=\(self.viewModel.currentTime)")

                // The thumb
                Rectangle()
                    .fill(thumbColor)
                    .frame(width: thumbWidth, height: thumbHeight)
                    .cornerRadius(thumbHeight / 4)
                    .position(x: 0, y: sliderHeight)
                    .offset(x: convertValueToThumbOffset(for: self.viewModel.currentTime, width: geometry.size.width))
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
        self.selectionStart = 0.0
        self.selectionEnd = 0.0
        self.shiftPressed = false
    }
    
    // Convert tap point to a slider value
    func convertValue(for point: CGPoint, width: CGFloat) -> Double {
        let percentage = Double(point.x / width)
        return viewModel.duration * percentage
    }
    
    // Convert slider value to thumb x coordinate
    func convertValueToThumbOffset(for value: Double, width: CGFloat) -> CGFloat {
        let percentage: CGFloat = CGFloat(value / viewModel.duration)
        return (width * percentage)
    }
    
    // Handle the selection logic
    func handleTap(point: CGPoint, width: CGFloat) {
        let tappedValue = convertValue(for: point, width: width)
        
        if self.shiftPressed {
            // Shift-click: Expand the range
            self.selectionStart = min(self.selectionStart, tappedValue)
            self.selectionEnd = max(self.selectionEnd, tappedValue)
        } else {
            // Regular click: Set a single point (or the start of a new range)
            self.selectionStart = tappedValue
            self.selectionEnd = tappedValue
        }
        self.viewModel.seek(to: Double(tappedValue))
    }
    
    func handleDrag(point: CGPoint, width: CGFloat) {
        let newMovieOffset = convertValue(for: point, width: width)
        self.viewModel.seek(to: newMovieOffset)
    }
    
    func handleRightArrow() {
        self.viewModel.stepForward()
    }
    
    func handleLeftArrow() {
        self.viewModel.stepBackward()
    }
    
    // Helper to calculate the visual width of the selected range
    func selectionWidth( _ width: CGFloat) -> CGFloat {
        let totalRange = self.viewModel.duration
        let selectedRange = self.selectionEnd - self.selectionStart
        let output = CGFloat(selectedRange / totalRange) * width
        return output
    }
    
    // Helper to calculate the visual offset of the selected range
    func selectionOffset( _ width: CGFloat) -> CGFloat {
        let totalRange = self.viewModel.duration
        let offsetFromStart = self.selectionStart
        let output = CGFloat(offsetFromStart / totalRange) * width
        return output
    }
}
