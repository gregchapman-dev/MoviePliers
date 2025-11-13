//
//  MoviePliersApp.swift
//  MoviePliers
//
//  Created by Greg Chapman on 10/26/25.
//

import SwiftUI
import AVFoundation
import Observation
import Combine

@main
struct MoviePliersApp: App {
//    init() {
//        print("app init")
//    }

    var body: some Scene {
        WindowGroup(id: "movie-window", for: UUID.self) { movieID in
            if let identifier = movieID.wrappedValue {
                ContentView(movieID: identifier)
                    .navigationTitle(movieStore.getMovieInfo(for: identifier)?.windowTitle ?? "unknown")
            }
            else {
                MainView()
            }
        }
        .commands {
            MenuCommands()
        }
        .restorationBehavior(.disabled)

        Settings {
            // SettingsView()
        }
    }
}
