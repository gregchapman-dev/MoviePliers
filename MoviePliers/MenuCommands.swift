import Foundation
import SwiftUI
import Combine
import AVFoundation

// create an active viewmodel key
struct ActiveMovieIDKey: FocusedValueKey {
    typealias Value = Binding<UUID>
}

extension FocusedValues {
    var activeMovieID: Binding<UUID>? {
        get { self[ActiveMovieIDKey.self] }
        set { self[ActiveMovieIDKey.self] = newValue }
    }
}

var movieStore = MovieStore()

struct MenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedBinding(\.activeMovieID) var activeMovieID // get the active movie (the one in the focused view/window
    @State private var showingFileImporter = false
    
    func showSavePanel(suggestedFilename: String, viewModel: MovieViewModel) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export"
        savePanel.prompt = "Save"
        savePanel.nameFieldStringValue = suggestedFilename
        savePanel.canCreateDirectories = true
        savePanel.allowedContentTypes = [.quickTimeMovie, .mpeg4Movie]

        // Run the panel modally
        let response = savePanel.runModal()

        if response == .OK {
            if let url = savePanel.url {
                viewModel.save(url, selfContained: false)
            }
        }
    }
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") {
                let newMovieViewModel = movieStore.newMovieViewModel()
                openWindow(id: "movie-window", value: newMovieViewModel.id)
            }
            .keyboardShortcut("N", modifiers: .command)
            Button("Open...") {
                showingFileImporter = true
                print("open movie")
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.quickTimeMovie, .mpeg4Movie]) { result in
                switch result {
                case .success(let url):
                    // Handle the selected file URL here
                    print("Selected file URL: \(url)")
                    if let viewModel = try? movieStore.openMovie(at: url) {
                        openWindow(id: "movie-window", value: viewModel.id)
                    }
                    else {
                        print("could not open movie at URL: \(url)")
                    }
                case .failure(let error):
                    // Handle any errors that occurred during file picking
                    print("File import error: \(error.localizedDescription)")
                }
            }
            .keyboardShortcut("O", modifiers: .command)

//            Button("Open Image Sequence...") {
//                print("open image sequence")
//                let info = movieStore.openImageSequence(url: URL(string: "file://imageFolder")!)
//                openWindow(id: "movie-window", value: info.id)
//            }
        }
        CommandGroup(replacing: .saveItem) {
            Button("Close") {
                print("close movie")
                // print("activeMovieID = \($activeMovieInfo.id.uuidString)")
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        if viewModel.isModified {
                            print("need to save")
                        }
                        movieStore.removeMovieViewModel(for: viewModel.id)
                        print("removed")
                    }
                    else {
                        print("no movie info for activeMovieID: \(id.uuidString)")
                    }
                }
                else {
                    print("no activeMovieID")
                }
                NSApplication.shared.keyWindow?.close()
            }
            .keyboardShortcut("W", modifiers: .command)

            Button("Save") {
                print("save")
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        showSavePanel(suggestedFilename: "New Movie.mov", viewModel: viewModel)
                    }
                }
            }
            .keyboardShortcut("S", modifiers: .command)

            Button("Save As...") {
                print("save as")
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        showSavePanel(suggestedFilename: "New Movie.mov", viewModel: viewModel)
                    }
                }
            }
            Divider()
            Button("Export...") {
                print("export")
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        showSavePanel(suggestedFilename: "New Movie.mov", viewModel: viewModel)
                    }
                }
            }
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                print("undo")
            }.keyboardShortcut("Z", modifiers: .command)
            Button("Redo") {
                print("redo")
            }.keyboardShortcut("Z", modifiers: [.shift, .command])
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                print("cut")
            }.keyboardShortcut("X", modifiers: .command)

            Button("Copy") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        Task {
                            await viewModel.copy()
                        }
                    }
                }
            }.keyboardShortcut("C", modifiers: .command)
            Button("Paste") {
                print("paste")
            }.keyboardShortcut("V", modifiers: .command)
                .modifierKeyAlternate(.shift) {
                    Button("Replace") {
                        print("replace")
                    }
                }
                .modifierKeyAlternate(.option) {
                    Button("Add") {
                        if let id = activeMovieID {
                            if let viewModel = movieStore.getMovieViewModel(for: id) {
                                Task {
                                    await viewModel.add()
                                }
                            }
                        }
                    }
                }
                .modifierKeyAlternate([.option, .shift]) {
                    Button("Add Scaled") {
                        print("add scaled")
                    }
                }
            Button("Delete") {
                print("delete")
            }.keyboardShortcut(.delete, modifiers: [])
            Divider()
            Button("Select All") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.selectAll()
                    }
                }
            }.keyboardShortcut("A", modifiers: .command)
            Button("Select None") {
                print("select none")
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.selectNone()
                    }
                }
            }.keyboardShortcut("D", modifiers: .command)
            Divider()
            Button("Extract Tracks...") {
                print("extract tracks")
            }
            Button("Delete Tracks...") {
                print("delete tracks")
            }
            Button("Enable Tracks...") {
                print("enable tracks")
            }
            Divider()
            Button("Find...") {
                print("find")
            }.keyboardShortcut("F", modifiers: .command)
            Button("Find Again") {
                print("find again")
            }.keyboardShortcut("G", modifiers: .command)
        }

        CommandMenu("Movie") {
            Button("Get Info") {
                print("get info")
            }.keyboardShortcut("I", modifiers: .command)
            Button("Show Copyright") {
                print("show copyright etc")
            }
            Divider()
            Button("Loop") {
                print("loop")
            }.keyboardShortcut("L", modifiers: .command)
            Button("Loop Back and Forth") {
                print("loop back and forth")
            }
            Divider()
            Button("Play Selection Only") {
                print("play selection only")
            }.keyboardShortcut("T", modifiers: .command)
            Button("Play All Frames") {
                print("play all frames")
            }
            Divider()
            Button("Half Size") {
                print("half size")
            }.keyboardShortcut("0", modifiers: .command)
            Button("Normal Size") {
                print("normal size")
            }.keyboardShortcut("1", modifiers: .command)
            Button("Double Size") {
                print("double size")
            }.keyboardShortcut("2", modifiers: .command)
            Button("Fill Screen") {
                print("fill screen")
            }.keyboardShortcut("3", modifiers: .command)
            Divider()
            Button("Go To Poster Frame") {
                print("go to poster frame")
            }
            Button("Set Poster Frame") {
                print("set poster frame")
            }
            Divider()
            Button("Choose Language...") {
                print("choose language")
            }
        }
    }
}
