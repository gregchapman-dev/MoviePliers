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

// This is for intercepting clicks on the red "close" bubble in the window
class WindowCloser: NSObject, NSWindowDelegate {
    let viewModel: MovieViewModel?

    init(for viewModel: MovieViewModel?) {
        self.viewModel = viewModel
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if self.viewModel != nil && self.viewModel!.isModified {
            // Show alert and get user decision
            let alert = NSAlert()
            alert.messageText = "Discard changes?"
            alert.informativeText = "You have unsaved changes. Do you want to discard them and close the window?"
            alert.addButton(withTitle: "Discard Changes")
            alert.addButton(withTitle: "Cancel")
            
            // Display the alert modally
            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // User chose "Discard Changes", allow closing
                // But first restore originalDelegate (if there is one)
                if let originalDelegate = self.viewModel!.originalDelegate {
                    sender.delegate = originalDelegate
                }
                return true
            } else {
                // User chose "Cancel", prevent closing
                return false
            }
        }
        
        // No unsaved changes, allow closing
        // But first, restore originalDelegate if there is one
        if self.viewModel != nil {
            if let originalDelegate = self.viewModel!.originalDelegate {
                sender.delegate = originalDelegate
            }
        }
        return true
    }
}

struct ContentView: View {
    @State private var viewModel: MovieViewModel
    var body: some View {
        VStack {
            Text("movieID: \(viewModel.id)")
            MoviePlayerControlsView(viewModel: $viewModel)
        }
        .focusedSceneValue(\.activeMovieID, $viewModel.id) // stash off active movieID (when we have focus)
        .sheet(isPresented: $viewModel.extractTracksIsPresented) {
            // Present the extract tracks dialog when appropriate
            ExtractTracksDialogView(viewModel: $viewModel)
        }
        .sheet(isPresented: $viewModel.enableTracksIsPresented) {
            // Present the enable tracks dialog when appropriate
            EnableTracksDialogView(viewModel: $viewModel)
        }
        .sheet(isPresented: $viewModel.deleteTracksIsPresented) {
            // Present the delete tracks dialog when appropriate
            DeleteTracksDialogView(viewModel: $viewModel)
        }
        .background(
            HostingWindowFinder { window in
                viewModel.window = window
                viewModel.originalDelegate = window.delegate
                viewModel.myDelegate = WindowCloser(for: viewModel)
                // Setting window.delegate to our window closer, means that WindowCloser.windowShouldClose()
                // will be called if the red bubble in the window is clicked.  Other close methods are handled
                // more directly in viewModel.closeView(), which is called from Close in the menu.
                window.delegate = viewModel.myDelegate
            }
        )
    }

    init(movieID theID: UUID) {
        if !movieStore.contains(theID) {
            print("no movie (window going away, or preview)")
            // Just make one without contents (don't put it in the movieStore)
            self.viewModel = MovieViewModel()
        }
        else {
            self.viewModel = movieStore.getMovieViewModel(for: theID)!
            print("ContentView movie ID = \(self.viewModel.id)")
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
