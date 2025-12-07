//
//  ContentView.swift
//  MoviePliers
//
//  Created by Greg Chapman on 10/26/25.
//

import SwiftUI
import AVFoundation
import AVKit

struct HostingWindowFinder: NSViewRepresentable {
    // A callback to receive the NSWindow instance
    var onWindowFound: (NSWindow) -> Void

    func makeNSView(context: Self.Context) -> NSView {
        let view = NSView()
        // Use a main-thread async block to ensure the view has been added to the window hierarchy
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window {
                onWindowFound(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    @State private var movieViewModel: MovieViewModel
    var body: some View {
        VStack {
            Text("movieID: \(movieViewModel.id)")
            MoviePlayerControlsView(viewModel: $movieViewModel)
        }
        .focusedSceneValue(\.activeMovieID, $movieViewModel.id) // stash off active movieID (when we have focus)
        .background(
            HostingWindowFinder { window in
                movieViewModel.window = window
            }
        )
    }

    init(movieID theID: UUID) {
        if !movieStore.contains(theID) {
            print("no movie (window going away, or preview)")
            // Just make one without contents (don't put it in the movieStore)
            self.movieViewModel = MovieViewModel()
        }
        else {
            self.movieViewModel = movieStore.getMovieViewModel(for: theID)!
            print("ContentView movie ID = \(self.movieViewModel.id)")
        }
    }

    #Preview {
        ContentView(movieID: UUID())
    }
}

struct MainView: View {
    var body: some View {
        VStack {
            Text("main window (no content yet)")
        }
    }
}
