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
    @State private var movieID: UUID
    var body: some View {
        VStack {
            Text("movieID: \(movieID.uuidString)")
            VideoPlayer(player: movieStore.player(for: movieID))
        }
        .focusedSceneValue(\.activeMovieID, $movieID) // stash off active movieID (when we have focus)
    }

    init(movieID theID: UUID) {
        if !movieStore.contains(theID) {
            print("no movie (window going away, or preview)")
        }
        self.movieID = theID
        print("self.movieID = \(self.movieID)")
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
