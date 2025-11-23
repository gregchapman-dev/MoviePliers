import SwiftUI

struct SelectableRangeSlider: View {
    @ObservedObject var modifierKeyMonitor: ModifierKeyMonitor
    @State private var currentValue: Binding<Double>
    @State private var duration: Binding<Double>
    @State private var selectionStart: Double
    @State private var selectionEnd: Double
    @State private var lastClickedValue: Double?
//    @FocusState private var focused: Bool
    
    let sliderHeight: CGFloat = 10
    let trackColor = Color.gray
    let rangeColor = Color.blue
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
                    .fill(rangeColor)
                    .frame(width: selectionWidth(geometry.size.width), height: sliderHeight)
                    .offset(x: selectionOffset(geometry.size.width))
                    .cornerRadius(sliderHeight / 2)
            }
            .contentShape(Rectangle()) // Makes the whole area tappable
//            .focusable()
//            .focused($focused)
//            .onKeyPress(keys: [.rightArrow, .leftArrow]) { press in
//                if .rightArrow in press.characters {
//                    
//                    endValue += stepValue
//                }
//                else if .leftArrow in press.characters {
//                    DispatchQueue.main.async {
//                        endValue -= stepValue
//                    }
//                }
//                return .handled
//            }
            .onTapGesture { point in
                handleTap(point: point, width: geometry.size.width)
            }
//            .onAppear {
//                focused = true
//            }            
        }
        .frame(height: sliderHeight)
    }
    
    init(value: Binding<Double>, duration: Binding<Double>) {
        self.modifierKeyMonitor = ModifierKeyMonitor()
        self.selectionStart = value.wrappedValue
        self.selectionEnd = value.wrappedValue
        self.lastClickedValue = nil
        self.currentValue = value          // will update automatically as movie plays
        self.duration = duration    // will update automatically as movie is edited
    }
    
    // Convert tap point to a slider value
    func convertValue(for point: CGPoint, width: CGFloat) -> Double {
        let percentage = Double(point.x / width)
        return duration.wrappedValue * percentage
    }
    
    // Handle the selection logic
    func handleTap(point: CGPoint, width: CGFloat) {
        let tappedValue = convertValue(for: point, width: width)
        
        if modifierKeyMonitor.isShiftPressed, let lastValue = self.lastClickedValue {
            // Shift-click: Expand the range
            self.selectionStart = min(lastValue, tappedValue)
            self.selectionEnd = max(lastValue, tappedValue)
        } else {
            // Regular click: Set a single point (or the start of a new range)
            self.selectionStart = tappedValue
            self.selectionEnd = tappedValue
        }
        self.lastClickedValue = tappedValue
        self.currentValue.wrappedValue = tappedValue
    }
    
    // Helper to calculate the visual width of the selected range
    func selectionWidth( _ width: CGFloat) -> CGFloat {
        let totalRange = self.duration.wrappedValue
        let selectedRange = self.selectionEnd - self.selectionStart
        return CGFloat(selectedRange / totalRange) * width
    }
    
    // Helper to calculate the visual offset of the selected range
    func selectionOffset( _ width: CGFloat) -> CGFloat {
        let totalRange = self.duration.wrappedValue
        let offsetFromStart = self.selectionStart
        return CGFloat(offsetFromStart / totalRange) * width
    }
}
