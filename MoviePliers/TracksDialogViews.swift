import SwiftUI

struct ExtractTracksDialogView: View {
    @Binding var viewModel: MovieViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Extract Tracks")
                .font(.title)

            Button("Dismiss") {
                viewModel.extractTracksIsPresented = false // Dismiss the sheet by setting the binding to false
            }
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(minWidth: 400, minHeight: 200)
    }
}

struct DeleteTracksDialogView: View {
    @Binding var viewModel: MovieViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Delete Tracks")
                .font(.title)

            Button("Dismiss") {
                viewModel.deleteTracksIsPresented = false // Dismiss the sheet by setting the binding to false
            }
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(minWidth: 400, minHeight: 200)
    }
}

struct EnableTracksDialogView: View {
    @Binding var viewModel: MovieViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Enable Tracks")
                .font(.title)

            Button("Dismiss") {
                viewModel.enableTracksIsPresented = false // Dismiss the sheet by setting the binding to false
            }
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(minWidth: 400, minHeight: 200)
    }
}

