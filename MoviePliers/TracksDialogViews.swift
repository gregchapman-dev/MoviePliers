import SwiftUI

struct ExtractTracksDialogView: View {
    @Environment(\.openWindow) private var openWindow
    @Binding var viewModel: MovieViewModel
    @State private var selectedItems: Set<UUID> = []

    var body: some View {
        VStack {
            Text("Select tracks to extract")
            List(selection: $selectedItems) {
                ForEach($viewModel.trackInfos[1..<viewModel.trackInfos.count], id: \.id) { trackInfo in
                    Text(trackInfo.name.wrappedValue)
                }
            }
            
            HStack {
                Button("Extract") {
                    let trackViewModel = extractTracks(viewModel: viewModel, trackInfoIds: selectedItems)
                    openWindow(id: "movie-window", value: trackViewModel.id)
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
    @State private var selectedItems: Set<UUID> = []

    var body: some View {
        VStack {
            Text("Select tracks to delete")
            List(selection: $selectedItems) {
                ForEach($viewModel.trackInfos[1..<viewModel.trackInfos.count], id: \.id) { trackInfo in
                    Text(trackInfo.name.wrappedValue)
                }
            }
            
            HStack {
                Button("Delete", role: .destructive) {
                    deleteTracks(viewModel: viewModel, trackInfoIds: selectedItems)
                }
                Button("Dismiss") {
                    viewModel.deleteTracksIsPresented = false // Dismiss the sheet by setting the binding to false
                }
            }
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct EnableTracksDialogView: View {
    @Binding var viewModel: MovieViewModel

    var body: some View {
        VStack {
            Text("Enable tracks")
            List() {
                ForEach($viewModel.trackInfos[1..<viewModel.trackInfos.count], id: \.id) { trackInfo in
                    HStack {
                        Button(trackInfo.enabled.wrappedValue ? "On" : "Off") {
                            toggleTrackEnabled(viewModel: viewModel, trackInfo: trackInfo.wrappedValue)
                        }
                        Text(trackInfo.name.wrappedValue)
                    }
                }
            }
            
            Button("Dismiss") {
                viewModel.enableTracksIsPresented = false // Dismiss the sheet by setting the binding to false
            }
        }
        .padding(50) // Add padding for better appearance on macOS sheets
        .frame(minWidth: 400, minHeight: 300)
    }
}
