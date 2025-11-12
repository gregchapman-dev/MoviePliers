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
    @Bindable private var movieInfo: MovieInfo
    var body: some View {
        VStack {
            Text("movieID: \(movieInfo.id.uuidString)")
            VideoPlayer(player: movieInfo.player)
        }
        .focusedSceneValue(\.activeMovieID, $movieInfo.id) // stash off active movieID (when we have focus)
    }

    init(movieID theID: UUID) {
        if !movieStore.contains(theID) {
            print("no movie (window going away, or preview)")
            // Just make one without contents (don't put it in the movieStore)
            self.movieInfo = MovieInfo()
        }
        else {
            self.movieInfo = movieStore.getMovieInfo(for: theID)!
            print("ContentView movie ID = \(self.movieInfo.id.uuidString)")
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
