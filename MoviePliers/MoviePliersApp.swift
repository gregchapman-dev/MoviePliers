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
    init() {
        if #available(macOS 26.0, *) {
            AVPlayer.isObservationEnabled = true
        } else {
            // Fallback on earlier versions
        }
    }

    var body: some Scene {
        WindowGroup(id: "movie-window", for: UUID.self) { movieID in
            if let identifier = movieID.wrappedValue {
                ContentView(movieID: identifier)
                    .navigationTitle(movieStore.getMovieViewModel(for: identifier)?.windowTitle ?? "unknown")
            }
            else {
                // If we ever have an initial window like Xcode does, uncomment this.
                //MainView()
            }
        }
        .commands {
            MenuCommands()
        }
        .restorationBehavior(.disabled)
        .defaultWindowPlacement { content, context in
            let size = content.sizeThatFits(.unspecified)
            //let displayBounds = context.defaultDisplay.visibleRect
            return WindowPlacement(size: size)
        }

        WindowGroup(id: "get-info-window", for: UUID.self) { movieID in
            if let identifier = movieID.wrappedValue {
                GetInfoView(movieID: identifier)
                    .navigationTitle(movieStore.getMovieViewModel(for: identifier)?.windowTitle ?? "unknown")
            }
        }
        .commands {
            MenuCommandsWithoutMovie()
        }
        .restorationBehavior(.disabled)

        Settings {
            // SettingsView()
        }
    }
}
