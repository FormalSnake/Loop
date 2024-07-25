//
//  WindowEngine.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import Defaults
import SwiftUI

enum WindowEngine {
    /// Resize a Window
    /// - Parameters:
    ///   - window: Window to be resized
    ///   - direction: WindowDirection
    ///   - screen: Screen the window should be resized on
    static func resize(
        _ window: Window,
        to action: WindowAction,
        on screen: NSScreen
    ) {
        guard action.direction != .noAction else { return }
        let willChangeScreens = ScreenManager.screenContaining(window) != screen

        let windowTitle = window.nsRunningApplication?.localizedName ?? window.title ?? "<unknown>"
        print("Resizing \(windowTitle) to \(action.direction) on \(screen.localizedName)")

        // Note that this is only really useful when "Resize window under cursor" is enabled
        if Defaults[.focusWindowOnResize] {
            window.activate()
        }

        if !WindowRecords.hasBeenRecorded(window) {
            WindowRecords.recordFirst(for: window)
        }

        if action.direction == .fullscreen {
            window.toggleFullscreen()
            WindowRecords.record(window, action)
            return
        }
        window.fullscreen = false

        if action.direction == .hide {
            window.toggleHidden()
            return
        }

        if action.direction == .minimize {
            window.toggleMinimized()
            return
        }

        let targetFrame = action.getFrame(window: window, bounds: screen.safeScreenFrame, screen: screen)

        if action.direction == .undo {
            WindowRecords.removeLastAction(for: window)
        }

        print("Target window frame: \(targetFrame)")

        let enhancedUI = window.enhancedUserInterface
        let animate = Defaults[.animateWindowResizes] && !enhancedUI
        WindowRecords.record(window, action)

        if window.nsRunningApplication == NSRunningApplication.current,
           let window = NSApp.keyWindow {
            var newFrame = targetFrame
            newFrame.size = window.frame.size

            if newFrame.maxX > screen.safeScreenFrame.maxX {
                newFrame.origin.x = screen.safeScreenFrame.maxX - newFrame.width - Defaults[.padding].right
            }

            if newFrame.maxY > screen.safeScreenFrame.maxY {
                newFrame.origin.y = screen.safeScreenFrame.maxY - newFrame.height - Defaults[.padding].bottom
            }

            NSAnimationContext.runAnimationGroup { context in
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.33, 1, 0.68, 1)
                window.animator().setFrame(newFrame.flipY(screen: .screens[0]), display: false)
            }

            return
        }

        let screenFrame = action.direction.willMove ? .zero : screen.safeScreenFrame

        let bounds = if Defaults[.enablePadding],
                        Defaults[.paddingMinimumScreenSize] == 0 || screen.diagonalSize > Defaults[.paddingMinimumScreenSize] {
            Defaults[.padding].apply(on: screenFrame)
        } else {
            screenFrame
        }

        window.setFrame(
            targetFrame,
            animate: animate,
            sizeFirst: willChangeScreens,
            bounds: bounds
        ) {
            // If animations are disabled, check if the window needs extra resizing
            if !animate {
                // Fixes an issue where window isn't resized correctly on multi-monitor setups
                if !window.frame.approximatelyEqual(to: targetFrame) {
                    print("Backup resizing...")
                    window.setFrame(targetFrame)
                }
            }

            WindowEngine.handleSizeConstrainedWindow(window: window, bounds: bounds)
        }

        if Defaults[.moveCursorWithWindow] {
            CGWarpMouseCursorPosition(targetFrame.center)
        }
    }

    static func getTargetWindow() -> Window? {
        var result: Window?

        do {
            if Defaults[.resizeWindowUnderCursor],
               let mouseLocation = CGEvent.mouseLocation,
               let window = try WindowEngine.windowAtPosition(mouseLocation) {
                result = window
            }
        } catch {
            print("Failed to get window at cursor: \(error.localizedDescription)")
        }

        if result == nil {
            do {
                result = try WindowEngine.getFrontmostWindow()
            } catch {
                print("Failed to get frontmost window: \(error.localizedDescription)")
            }
        }
        
      
        return result
    }

    /// Get the frontmost Window
    /// - Returns: Window?
    static func getFrontmostWindow() throws -> Window? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.isActive }) else {
            return nil
        }
        return try Window(pid: app.processIdentifier)
    }

    static func windowAtPosition(_ position: CGPoint) throws -> Window? {
        if let element = try AXUIElement.systemWide.getElementAtPosition(position),
           let windowElement: AXUIElement = try element.getValue(.window) {
            return try Window(element: windowElement)
        }

        let windowList = WindowEngine.windowList
        if let window = (windowList.first { $0.frame.contains(position) }) {
            return window
        }

        return nil
    }

    static var windowList: [Window] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as NSArray? as? [[String: AnyObject]] else {
            return []
        }

        var windowList: [Window] = []
        for window in list {
            if let pid = window[kCGWindowOwnerPID as String] as? Int32 {
                do {
                    let window = try Window(pid: pid)
                    windowList.append(window)
                } catch {
                    print("Failed to create window: \(error.localizedDescription)")
                }
            }
        }

        return windowList
    }

    static func getMacOSCenterYOffset(_ windowHeight: CGFloat, screenHeight: CGFloat) -> CGFloat {
        let halfScreenHeight = screenHeight / 2
        let windowHeightPercent = windowHeight / screenHeight
        return (0.5 * windowHeightPercent - 0.5) * halfScreenHeight
    }

    /// Will move a window back onto the screen. To be run AFTER a window has been resized.
    /// - Parameters:
    ///   - window: Window
    ///   - screenFrame: The screen's frame
    private static func handleSizeConstrainedWindow(window: Window, bounds: CGRect) {
        guard bounds != .zero else {
            return
        }

        var windowFrame = window.frame

        // If the window is fully shown on the screen
        if windowFrame.maxX <= bounds.maxX,
           windowFrame.maxY <= bounds.maxY {
            return
        }

        if windowFrame.maxX > bounds.maxX {
            windowFrame.origin.x = bounds.maxX - windowFrame.width
        }

        if windowFrame.maxY > bounds.maxY {
            windowFrame.origin.y = bounds.maxY - windowFrame.height
        }

        window.position = windowFrame.origin
    }
}
