import SwiftUI

struct ExtractTracksDialogView: View {
    @Environment(\.openWindow) private var openWindow
    @Binding var viewModel: MovieViewModel
    @State private var selectedItems: Set<UUID> = []

    var body: some View {
        VStack {
            Text("Select tracks to extract")
            List(selection: $selectedItems) {
                ForEach($viewModel.trackInfos, id: \.id) { trackInfo in
                    HStack {
                        Text(trackInfo.name.wrappedValue)
                    }
                }
            }
            
            HStack {
                Button() {
                    let trackViewModel = extractTracks(viewModel: viewModel, trackInfoIds: selectedItems)
                    openWindow(id: "movie-window", value: trackViewModel.id)
                } label: {
                    Text("Extract")
                }
                Button("Dismiss") {
                    viewModel.extractTracksIsPresented = false // Dismiss the sheet by setting the binding to false
                }
            }
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(minWidth: 400, minHeight: 300)
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

