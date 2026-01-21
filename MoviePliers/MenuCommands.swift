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

let contentTypes = AVURLAsset.audiovisualTypes().compactMap { $0.utType }

struct MenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedBinding(\.activeMovieID) var activeMovieID // get the active movie (the one in the focused view/window
    @State private var showingFileImporter = false
    
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
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: contentTypes) { result in
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
                // print("activeMovieID = \($activeMovieInfo.id.uuidString)")
                if let id = activeMovieID, let viewModel = movieStore.getMovieViewModel(for: id) {
                    viewModel.closeView()
                    return
                }
                print("no activeMovieID or no viewModel for activeMovieID, closing key window instead")
                NSApplication.shared.keyWindow?.close()
            }
            .keyboardShortcut("W", modifiers: .command)

            Button("Save") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.saveOrSaveAs()
                    }
                }
            }
            .keyboardShortcut("S", modifiers: .command)

            Button("Save As...") {
                print("save as")
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.showSaveAsPanel(suggestedFilename: "New Movie.mov")
                    }
                }
            }
            Divider()
            Button("Export...") {
                print("export")
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        // TODO: replace with export panel (allowing selection of codecs, and file formats like AVI).
                        viewModel.showSaveAsPanel(suggestedFilename: "New Movie.mov")
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
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.cut()
                    }
                }
            }.keyboardShortcut("X", modifiers: .command)

            Button("Copy") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.copy()
                    }
                }
            }.keyboardShortcut("C", modifiers: .command)
            Button("Paste") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.paste()
                    }
                }
            }.keyboardShortcut("V", modifiers: .command)
                .modifierKeyAlternate(.shift) {
                    Button("Replace") {
                        if let id = activeMovieID {
                            if let viewModel = movieStore.getMovieViewModel(for: id) {
                                viewModel.replace()
                            }
                        }
                    }
                }
                .modifierKeyAlternate(.option) {
                    Button("Add") {
                        if let id = activeMovieID {
                            if let viewModel = movieStore.getMovieViewModel(for: id) {
                                viewModel.add()
                            }
                        }
                    }
                }
                .modifierKeyAlternate([.option, .shift]) {
                    Button("Add Scaled") {
                        if let id = activeMovieID {
                            if let viewModel = movieStore.getMovieViewModel(for: id) {
                                viewModel.addScaled()
                            }
                        }
                    }
                }
            Button("Clear") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.clear()
                    }
                }
            }.keyboardShortcut(.delete, modifiers: [])
                .modifierKeyAlternate(.option) {
                    Button("Trim") {
                        if let id = activeMovieID {
                            if let viewModel = movieStore.getMovieViewModel(for: id) {
                                viewModel.trim()
                            }
                        }
                   }
                }
            Divider()
            Button("Select All") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.selectAll()
                    }
                }
            }.keyboardShortcut("A", modifiers: .command)
            Button("Select...") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.selectIsPresented = true
                    }
                }
            }
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
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.extractTracksIsPresented = true
                    }
                }
            }
            Button("Delete Tracks...") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.deleteTracksIsPresented = true
                    }
                }
            }
            Button("Enable Tracks...") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.enableTracksIsPresented = true
                    }
                }
            }
            Divider()
            Button("Go To...") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.gotoTimeIsPresented = true
                    }
                }
            }
            Button("Find...") {
                print("find")
            }.keyboardShortcut("F", modifiers: .command)
            Button("Find Again") {
                print("find again")
            }.keyboardShortcut("G", modifiers: .command)
        }

        CommandMenu("Movie") {
//            Button("Run Test") {
//                print("run test")
//                if let id = activeMovieID {
//                    if let viewModel = movieStore.getMovieViewModel(for: id) {
//                        viewModel.runCursorTest()
//                    }
//                }
//            }
            Button("Get Info") {
                if let id = activeMovieID {
                    if let _ = movieStore.getMovieViewModel(for: id) {
                        openWindow(id: "get-info-window", value: id)
                    }
                }
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

struct MenuCommandsWithoutMovie: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedBinding(\.activeMovieID) var activeMovieID // get the active movie (the one in the focused view/window
    @State private var showingFileImporter = false
    
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
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: contentTypes) { result in
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
                // print("activeMovieID = \($activeMovieInfo.id.uuidString)")
                if let id = activeMovieID, let viewModel = movieStore.getMovieViewModel(for: id) {
                    viewModel.closeView()
                    return
                }
                print("no activeMovieID or no viewModel for activeMovieID, closing key window instead")
                NSApplication.shared.keyWindow?.close()
            }
            .keyboardShortcut("W", modifiers: .command)

            Button("Save") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.saveOrSaveAs()
                    }
                }
            }
            .keyboardShortcut("S", modifiers: .command)

            Button("Save As...") {
                print("save as")
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.showSaveAsPanel(suggestedFilename: "New Movie.mov")
                    }
                }
            }
            Divider()
            Button("Export...") {
                print("export")
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        // TODO: replace with export panel (allowing selection of codecs, and file formats like AVI).
                        viewModel.showSaveAsPanel(suggestedFilename: "New Movie.mov")
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
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.cut()
                    }
                }
            }.keyboardShortcut("X", modifiers: .command)

            Button("Copy") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.copy()
                    }
                }
            }.keyboardShortcut("C", modifiers: .command)
            Button("Paste") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.paste()
                    }
                }
            }.keyboardShortcut("V", modifiers: .command)
                .modifierKeyAlternate(.shift) {
                    Button("Replace") {
                        if let id = activeMovieID {
                            if let viewModel = movieStore.getMovieViewModel(for: id) {
                                viewModel.replace()
                            }
                        }
                    }
                }
                .modifierKeyAlternate(.option) {
                    Button("Add") {
                        if let id = activeMovieID {
                            if let viewModel = movieStore.getMovieViewModel(for: id) {
                                viewModel.add()
                            }
                        }
                    }
                }
                .modifierKeyAlternate([.option, .shift]) {
                    Button("Add Scaled") {
                        if let id = activeMovieID {
                            if let viewModel = movieStore.getMovieViewModel(for: id) {
                                viewModel.addScaled()
                            }
                        }
                    }
                }
            Button("Clear") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.clear()
                    }
                }
            }.keyboardShortcut(.delete, modifiers: [])
                .modifierKeyAlternate(.option) {
                    Button("Trim") {
                        if let id = activeMovieID {
                            if let viewModel = movieStore.getMovieViewModel(for: id) {
                                viewModel.trim()
                            }
                        }
                   }
                }
            Divider()
            Button("Select All") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.selectAll()
                    }
                }
            }.keyboardShortcut("A", modifiers: .command)
            Button("Select...") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.selectIsPresented = true
                    }
                }
            }
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
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.extractTracksIsPresented = true
                    }
                }
            }
            Button("Delete Tracks...") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.deleteTracksIsPresented = true
                    }
                }
            }
            Button("Enable Tracks...") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.enableTracksIsPresented = true
                    }
                }
            }
            Divider()
            Button("Go To...") {
                if let id = activeMovieID {
                    if let viewModel = movieStore.getMovieViewModel(for: id) {
                        viewModel.gotoTimeIsPresented = true
                    }
                }
            }
            Button("Find...") {
                print("find")
            }.keyboardShortcut("F", modifiers: .command)
            Button("Find Again") {
                print("find again")
            }.keyboardShortcut("G", modifiers: .command)
        }
    }
}

func extractTracks(viewModel: MovieViewModel, trackInfoIds: Set<UUID>) -> MovieViewModel {
    let trackInfos: [TrackInfo] = viewModel.trackInfosForIds(trackInfoIds: trackInfoIds)

    let trackMovieViewModel = movieStore.newMovieViewModel()
    for trackInfo in trackInfos {
        print("extracting: \(trackInfo.name)")
        trackMovieViewModel.addTrack(trackInfo)
    }
    return trackMovieViewModel
}

func deleteTracks(viewModel: MovieViewModel, trackInfoIds: Set<UUID>) {
    let trackInfos: [TrackInfo] = viewModel.trackInfosForIds(trackInfoIds: trackInfoIds)

    for trackInfo in trackInfos {
        print("deleting: \(trackInfo.name)")
        viewModel.deleteTrack(trackInfo)
    }
}

func toggleTrackEnabled(viewModel: MovieViewModel, trackInfo: TrackInfo) {
    viewModel.toggleTrackEnabled(trackInfo)
}
