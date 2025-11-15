import SwiftUI
import AppKit
import AVKit
import AVFoundation

public struct MovieView: NSViewRepresentable {
    
    @Binding var viewModel: MovieViewModel
    
    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let playerLayer = AVPlayerLayer(player: viewModel.player)
        playerLayer.videoGravity = .resizeAspect
        view.layer = playerLayer
        view.wantsLayer = true
        return view
    }
    
    public func updateNSView(_ nsView: NSView, context: Context) {
        guard let playerLayer = nsView.layer as? AVPlayerLayer else { return }
        playerLayer.player = viewModel.player
    }
}
