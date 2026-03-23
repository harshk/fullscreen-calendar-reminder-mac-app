//
//  NativeContextMenu.swift
//  ZapCal
//
//  Native NSMenu context menu for SwiftUI views.
//  Avoids SwiftUI's .contextMenu which leaks NSHostingView state on each presentation.
//

import SwiftUI
import AppKit

// MARK: - Closure-based NSMenuItem

/// NSMenuItem that invokes a closure when selected — avoids SwiftUI's
/// leaky context menu implementation.
class ClosureMenuItem: NSMenuItem {
    private let closure: () -> Void

    init(_ title: String, _ closure: @escaping () -> Void) {
        self.closure = closure
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        self.target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func invoke() {
        closure()
    }
}

// MARK: - Native Context Menu View Modifier

extension View {
    /// Attach a native NSMenu context menu to a SwiftUI view.
    /// Unlike SwiftUI's `.contextMenu`, this doesn't leak NSHostingView state.
    func nativeContextMenu(_ menuBuilder: @escaping () -> NSMenu) -> some View {
        self.overlay(
            NativeContextMenuHelper(menuBuilder: menuBuilder)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}

/// Invisible NSViewRepresentable that intercepts right-clicks and shows an NSMenu.
struct NativeContextMenuHelper: NSViewRepresentable {
    let menuBuilder: () -> NSMenu

    func makeNSView(context: Context) -> NativeContextMenuView {
        let view = NativeContextMenuView()
        view.menuBuilder = menuBuilder
        return view
    }

    func updateNSView(_ nsView: NativeContextMenuView, context: Context) {
        nsView.menuBuilder = menuBuilder
    }
}

class NativeContextMenuView: NSView {
    var menuBuilder: (() -> NSMenu)?

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuBuilder?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    // Pass through left clicks to the SwiftUI view below
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only intercept right clicks
        let event = NSApp.currentEvent
        if event?.type == .rightMouseDown {
            return super.hitTest(point)
        }
        return nil
    }
}
