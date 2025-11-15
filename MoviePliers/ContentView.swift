//
//  ContentView.swift
//  MoviePliers
//
//  Created by Greg Chapman on 10/26/25.
//

import SwiftUI
import AVFoundation
import AVKit

struct ContentView: View {
    @Bindable private var movieViewModel: MovieViewModel
    var body: some View {
        VStack {
            Text("movieID: \(movieViewModel.id)")
            VideoPlayer(player: movieViewModel.player)
        }
        .focusedSceneValue(\.activeMovieID, $movieViewModel.id) // stash off active movieID (when we have focus)
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
