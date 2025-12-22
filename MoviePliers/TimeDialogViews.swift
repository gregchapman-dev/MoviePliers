import SwiftUI
import AVFoundation

struct SelectionDialogView: View {
    @Environment(\.openWindow) private var openWindow
    @Binding var viewModel: MovieViewModel
    @State private var newSelection: CMTimeRange? = nil

    var body: some View {
        VStack {
            Text("Enter selection start and duration (or end):")
            
            HStack {
                Button("OK") {
                    viewModel.selection = newSelection
                    viewModel.selectIsPresented = false // Dismiss the sheet
                }
                Button("Cancel") {
                    viewModel.selectIsPresented = false // Dismiss the sheet
                }
            }
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct GoToTimeDialogView: View {
    @Environment(\.openWindow) private var openWindow
    @Binding var viewModel: MovieViewModel
    @State private var newTime: CMTime? = nil

    var body: some View {
        VStack {
            Text("Enter time to go to:")
            
            HStack {
                Button("OK") {
                    if let newTime {
                        Task {
                            await viewModel.seek(to: newTime)
                        }
                    }
                    viewModel.gotoTimeIsPresented = false // Dismiss the sheet
                }
                Button("Cancel") {
                    viewModel.gotoTimeIsPresented = false // Dismiss the sheet
                }
            }
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(minWidth: 400, minHeight: 300)
    }
}

