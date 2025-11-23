import SwiftUI
import Combine
import AppKit

class ModifierKeyMonitor: ObservableObject {
    @Published var isShiftPressed: Bool = false
    //@Published var isOptionPressed: Bool = false
    private var eventMonitor: Any?

    init() {
        // Monitor global flags changed events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) 
        { [weak self] event in
            DispatchQueue.main.async {
                self?.isShiftPressed = event.modifierFlags.contains(.shift)
                //self?.isOptionPressed = event.modifierFlags.contains(.option)
            }
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
