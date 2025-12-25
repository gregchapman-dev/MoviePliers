import SwiftUI
import AVFoundation

struct SelectionDialogView: View {
    @Environment(\.openWindow) private var openWindow
    @Binding var viewModel: MovieViewModel
    @State private var newSelectionStart: CMTime?
    @State private var newSelectionDuration: CMTime?
    @State private var newSelectionEnd: CMTime?
    
    var body: some View {
        VStack {
            Text("Enter selection start and duration:")
            
            HStack {
                Text("Start:")
                TextField("hh:mm:ss.sss", value: $newSelectionStart, format: CMTimeHMSMillisFormatStyle(preferredTimeScale: viewModel.movieTimeScale ?? 1000))
            }
            HStack {
                Text("Start:")
                TextField("value/timescale", value: $newSelectionStart, format: .cmTimeFraction)
            }
            HStack {
                Text("End:")
                TextField("hh:mm:ss.sss", value: $newSelectionEnd, format: CMTimeHMSMillisFormatStyle(preferredTimeScale: viewModel.movieTimeScale ?? 1000))
                    .onChange(of: newSelectionEnd, initial: true) { oldValue, newValue in
                        onChangeOfSelectionEnd(oldValue, newValue)
                    }
            }
            HStack {
                Text("End:")
                TextField("value/timescale", value: $newSelectionEnd, format: .cmTimeFraction)
                    .onChange(of: newSelectionEnd, initial: true) { oldValue, newValue in
                        onChangeOfSelectionEnd(oldValue, newValue)
                    }
            }
            HStack {
                Text("Duration:")
                TextField("hh:mm:ss.sss", value: $newSelectionDuration, format: CMTimeHMSMillisFormatStyle(preferredTimeScale: viewModel.movieTimeScale ?? 1000))
                    .onChange(of: newSelectionDuration, initial: true) { oldValue, newValue in
                        onChangeOfSelectionDuration(oldValue, newValue)
                    }
            }
            HStack {
                Text("Duration:")
                TextField("value/timescale", value: $newSelectionDuration, format: .cmTimeFraction)
                    .onChange(of: newSelectionDuration, initial: true) { oldValue, newValue in
                        onChangeOfSelectionDuration(oldValue, newValue)
                    }
            }

            HStack {
                Button("OK", role: .destructive) {
                    if let newSelectionStart, let newSelectionEnd {
                        viewModel.selection = CMTimeRange(start: newSelectionStart, end: newSelectionEnd)
                    }
                    viewModel.selectIsPresented = false // Dismiss the sheet
                }
                Button("Cancel", role: .cancel) {
                    viewModel.selectIsPresented = false // Dismiss the sheet
                }
            }
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(minWidth: 400, minHeight: 300)
    }
    
    func onChangeOfSelectionStart(_ newValue: CMTime?) {
        
    }
    
    func onChangeOfSelectionEnd(_ oldEnd: CMTime?, _ newEnd: CMTime?) {
        if newEnd == nil {
            // initial case, initialize from viewModel
            newSelectionStart = viewModel.selection?.start
            newSelectionEnd = viewModel.selection?.end
            newSelectionDuration = viewModel.selection?.duration
            return
        }
        
        if newEnd == oldEnd {
            // we just tabbed or clicked into this textfield, no change at all (don't recompute anything!)
            return
        }
        
        if let timescale = viewModel.movieTimeScale {
            if let newSelEnd = newSelectionEnd, newSelEnd.timescale != timescale {
                newSelectionEnd = newSelEnd.convertScale(timescale, method: .roundHalfAwayFromZero)
            }
        }
        
        if let newSelectionStart, let newSelectionEnd {
            let newDuration = newSelectionEnd - newSelectionStart
            if let timescale = viewModel.movieTimeScale {
                newSelectionDuration = newDuration.convertScale(timescale, method: .roundHalfAwayFromZero)
            }
            else {
                newSelectionDuration = newDuration
            }
        }
    }
    
    func onChangeOfSelectionDuration(_ oldDuration: CMTime?, _ newDuration: CMTime?) {
        if newDuration == nil {
            // initial case, initialize from viewModel
            newSelectionStart = viewModel.selection?.start
            newSelectionEnd = viewModel.selection?.end
            newSelectionDuration = viewModel.selection?.duration
            return
        }
        
        if newDuration == oldDuration {
            // we just tabbed or clicked into this textfield, no change at all (don't recompute anything!)
            return
        }
        
        if let timescale = viewModel.movieTimeScale {
            if let newDur = newSelectionDuration, newDur.timescale != timescale {
                newSelectionDuration = newDur.convertScale(timescale, method: .roundHalfAwayFromZero)
            }
        }
        
        if let newSelectionStart, let newSelectionDuration {
            let newEnd = newSelectionStart + newSelectionDuration
            if let timescale = viewModel.movieTimeScale {
                newSelectionEnd = newEnd.convertScale(timescale, method: .roundHalfAwayFromZero)
            }
            else {
                newSelectionEnd = newEnd
            }
        }
    }
}

struct GoToTimeDialogView: View {
    @Environment(\.openWindow) private var openWindow
    @Binding var viewModel: MovieViewModel
    @State private var newTime: CMTime? = nil

    var body: some View {
        VStack {
            Text("Enter time to go to:")

            TextField("Time (hh:mm:ss.sss)", value: $newTime, format: CMTimeHMSMillisFormatStyle(preferredTimeScale: viewModel.movieTimeScale ?? 1000))
            TextField("Time (value/timescale)", value: $newTime, format: .cmTimeFraction)

            HStack {
                Button("OK", role: .destructive) {
                    if let newTime {
                        Task {
                            await viewModel.seek(to: newTime)
                        }
                    }
                    viewModel.gotoTimeIsPresented = false // Dismiss the sheet
                }
                Button("Cancel", role: .cancel) {
                    viewModel.gotoTimeIsPresented = false // Dismiss the sheet
                }
            }
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(minWidth: 400, minHeight: 300)
    }
}

extension FormatStyle where Self == CMTimeFractionFormatStyle {
    static var cmTimeFraction: CMTimeFractionFormatStyle {
        CMTimeFractionFormatStyle()
    }
}

struct CMTimeFractionParseStrategy: ParseStrategy {
    typealias Input = String
    typealias Output = CMTime

    enum FormattingError: Error {
        case invalidCMTimeFraction
    }

    func parse(_ value: String) throws -> CMTime {
        if value.isEmpty {
            throw FormattingError.invalidCMTimeFraction
        }
        let values: [Substring] = value.split(separator: "/")
        if values.count != 2 {
            throw FormattingError.invalidCMTimeFraction
        }
        guard let numValue = CMTimeValue(values[0]), let denValue = CMTimeScale(values[1]) else {
            throw FormattingError.invalidCMTimeFraction
        }
        return CMTime(value: numValue, timescale: denValue)
    }
}

struct CMTimeFractionFormatStyle: ParseableFormatStyle {
    typealias FormatInput = CMTime
    typealias FormatOutput = String

    // Defines how the CMTime data is displayed as a String in the UI
    func format(_ value: CMTime) -> String {
        if value == .invalid { return "nan" }
        if value == .indefinite { return "indefinite" }
        if value == .negativeInfinity { return "-inf" }
        if value == .positiveInfinity { return "+inf" }
        if value == .zero { return "0/1" }
        return String(format: "%ld/%d", value.value, value.timescale)
    }

    // Defines how the String input from the user is parsed back into the CMTime data
    var parseStrategy: CMTimeFractionParseStrategy {
        CMTimeFractionParseStrategy()
    }
}

struct CMTimeHMSMillisParseStrategy: ParseStrategy {
    typealias Input = String
    typealias Output = CMTime

    enum FormattingError: Error {
        case invalidCMTimeHMSMillis
    }
    
    var preferredTimeScale: CMTimeScale
    
    init(preferredTimeScale: CMTimeScale = 1000) {
        self.preferredTimeScale = preferredTimeScale
    }
    
    func parse(_ value: String) throws -> CMTime {
        if value.isEmpty {
            throw FormattingError.invalidCMTimeHMSMillis
        }
        let values: [Substring] = value.split(separator: ":")
        if values.isEmpty {
            throw FormattingError.invalidCMTimeHMSMillis
        }
        if values.count > 3 {
            throw FormattingError.invalidCMTimeHMSMillis
        }
        
        let parts: [Substring] = values.last!.split(separator: ".")
        if parts.count > 2 {
            throw FormattingError.invalidCMTimeHMSMillis
        }
        var milliseconds: Int = 0
        var seconds: Int = 0
        var minutes: Int = 0
        var hours: Int = 0
        if parts.count == 2 {
            let part1 = parts[1]
            let count = part1.index(part1.startIndex, offsetBy: min(3, part1.count))
            let decimalPart = part1[..<count] // "Hello"
            guard let optionalDecimal = Int(decimalPart), let optionalSeconds = Int(parts[0]) else {
                throw FormattingError.invalidCMTimeHMSMillis
            }
            if decimalPart.count == 1 {
                milliseconds = optionalDecimal * 100
            }
            else if decimalPart.count == 2 {
                milliseconds = optionalDecimal * 10
            }
            else if decimalPart.count == 3 {
                milliseconds = optionalDecimal
            }
            seconds = optionalSeconds
        }
        else {
            // no milliseconds
            guard let optionalSeconds = Int(parts[0]) else {
                throw FormattingError.invalidCMTimeHMSMillis
            }
            seconds = optionalSeconds
        }
        
        if values.count == 2 {
            guard let optionalMinutes = Int(values[0]) else {
                throw FormattingError.invalidCMTimeHMSMillis
            }
            minutes = optionalMinutes
        }
        else if values.count == 3 {
            guard let optionalHours = Int(values[0]), let optionalMinutes = Int(values[1]) else {
                throw FormattingError.invalidCMTimeHMSMillis
            }
            minutes = optionalMinutes
            hours = optionalHours
        }
        
        let totalSeconds: Int64 = Int64(hours) * 3600 + Int64(minutes) * 60 + Int64(seconds)
        return CMTime(
            value: (totalSeconds * Int64(self.preferredTimeScale))
                + (Int64(milliseconds) * Int64(self.preferredTimeScale) / Int64(1000)),
            timescale: self.preferredTimeScale)
    }
}

struct CMTimeHMSMillisFormatStyle: ParseableFormatStyle {
    typealias FormatInput = CMTime
    typealias FormatOutput = String

    var preferredTimeScale: CMTimeScale
    
    // Defines how the String input from the user is parsed back into the CMTime data
    var parseStrategy: CMTimeHMSMillisParseStrategy


    init(preferredTimeScale: CMTimeScale = 1000) {
        self.preferredTimeScale = preferredTimeScale
        self.parseStrategy = CMTimeHMSMillisParseStrategy(preferredTimeScale: preferredTimeScale)
    }

    // Defines how the CMTime data is displayed as a String (hh:mm:ss.sss) in the UI
    func format(_ value: CMTime) -> String {
        if value == .invalid { return "nan" }
        if value == .indefinite { return "indefinite" }
        if value == .negativeInfinity { return "-inf" }
        if value == .positiveInfinity { return "+inf" }
        if value == .zero { return "00:00:00.000" }

        let timeInSeconds: Double = value.seconds
        var seconds: Int = Int(timeInSeconds)
        let hours: Int = seconds / 3600
        seconds -= hours * 3600
        let minutes: Int = seconds / 60
        seconds -= minutes * 60
        let millisecs: Int = Int(round((timeInSeconds - Double(Int(timeInSeconds))) * 1000.0))
        return String(format: "%d:%02d:%02d.%03d", hours, minutes, seconds, millisecs)
    }
}
