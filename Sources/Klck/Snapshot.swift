#if os(macOS)
import AppKit
import SwiftUI

/// `Klck --snapshot out.png [--size 620x880]` renders the main window to a PNG
/// and exits without showing anything on screen. It lets agents and scripts
/// check UI changes without driving the desktop (`make snapshot`).
///
/// It draws through an offscreen `NSHostingView` instead of `ImageRenderer`,
/// because `ImageRenderer` on macOS leaves AppKit-backed controls (sliders,
/// pickers, scroll views) blank.
@MainActor
enum Snapshot {
    static func runIfRequested(arguments: [String] = CommandLine.arguments) {
        guard let index = arguments.firstIndex(of: "--snapshot") else { return }
        guard index + 1 < arguments.count else { fail("--snapshot needs an output path") }
        let url = URL(fileURLWithPath: arguments[index + 1])

        var size = CGSize(width: 620, height: 880)
        if let sizeIndex = arguments.firstIndex(of: "--size"), sizeIndex + 1 < arguments.count {
            let parts = arguments[sizeIndex + 1].split(separator: "x").compactMap { Double($0) }
            guard parts.count == 2 else { fail("--size wants WIDTHxHEIGHT, like 620x880") }
            size = CGSize(width: parts[0], height: parts[1])
        }

        NSApplication.shared.setActivationPolicy(.prohibited)

        let view = ContentView()
            .environmentObject(MetronomeModel())
            .environmentObject(Tuner())
            .frame(width: size.width, height: size.height)
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)

        // A borderless window that is never ordered front gives SwiftUI a real
        // AppKit hierarchy to lay out in, so controls draw like they do live.
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless,
                              backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        // One run-loop turn lets SwiftUI finish its first update pass.
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            fail("could not allocate a bitmap")
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            fail("could not encode PNG")
        }
        do {
            try png.write(to: url)
        } catch {
            fail("could not write \(url.path): \(error.localizedDescription)")
        }
        print("snapshot: \(url.path) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
        exit(0)
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("snapshot: \(message)\n".utf8))
        exit(1)
    }
}
#endif
