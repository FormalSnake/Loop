//
//  WindowDragManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-04.
//

import Cocoa
import Defaults
import DynamicNotchKit

class WindowDragManager {
    var draggingWindow: Window?
    var initialWindowFrame: CGRect?

    let windowSnappingManager = WindowSnappingManager()
    let tooltipManager = TooltipManager()
    static let previewController = PreviewController()

    private var leftMouseDraggedMonitor: EventMonitor?
    private var leftMouseUpMonitor: EventMonitor?

    func addObservers() {
        leftMouseDraggedMonitor = CGEventMonitor(eventMask: .leftMouseDragged) { cgEvent in
            // Process window (only ONCE during a window drag)
            if self.draggingWindow == nil {
                self.setCurrentDraggingWindow()
            }

            if let window = self.draggingWindow,
               let initialFrame = self.initialWindowFrame,
               self.hasWindowMoved(window.frame, initialFrame) {
                if Defaults[.restoreWindowFrameOnDrag] {
                    self.restoreInitialWindowSize(window)
                } else {
                    WindowRecords.eraseRecords(for: window)
                }

                let showTooltip = Defaults[.tooltip]
                let windowSnapping = Defaults[.windowSnapping]

                // This prevents Mission Control from activating
                if showTooltip || windowSnapping {
                    if let frame = NSScreen.main?.frame {
                        if NSEvent.mouseLocation.y == frame.maxY {
                            cgEvent.location.y -= 1
                        }
                    }
                }

                if Defaults[.tooltip] {
                    self.tooltipManager.showIfPossible()
                }

                if Defaults[.windowSnapping] {
                    self.windowSnappingManager.getWindowSnapDirection()
                }
            }

            return Unmanaged.passUnretained(cgEvent)
        }

        leftMouseUpMonitor = NSEventMonitor(scope: .global, eventMask: .leftMouseUp) { _ in
            if let window = self.draggingWindow,
               let initialFrame = self.initialWindowFrame,
               self.hasWindowMoved(window.frame, initialFrame) {
                if Defaults[.tooltip] {
                    self.tooltipManager.closeAndResize(window)
                }

                if Defaults[.windowSnapping] {
                    self.windowSnappingManager.closeAndResize(window)
                }
            }

            self.windowSnappingManager.reset()
            self.draggingWindow = nil
            WindowDragManager.previewController.close()
        }

        leftMouseDraggedMonitor!.start()
        leftMouseUpMonitor!.start()
    }

    private func setCurrentDraggingWindow() {
        guard let screen = NSScreen.screenWithMouse else {
            return
        }

        let mousePosition = NSEvent.mouseLocation.flipY(screen: screen)

        guard
            let draggingWindow = WindowEngine.windowAtPosition(mousePosition),
            !draggingWindow.isAppExcluded
        else {
            return
        }

        self.draggingWindow = draggingWindow
        initialWindowFrame = draggingWindow.frame
    }

    private func hasWindowMoved(_ windowFrame: CGRect, _ initialFrame: CGRect) -> Bool {
        !initialFrame.topLeftPoint.approximatelyEqual(to: windowFrame.topLeftPoint) &&
            !initialFrame.topRightPoint.approximatelyEqual(to: windowFrame.topRightPoint) &&
            !initialFrame.bottomLeftPoint.approximatelyEqual(to: windowFrame.bottomLeftPoint) &&
            !initialFrame.bottomRightPoint.approximatelyEqual(to: windowFrame.bottomRightPoint)
    }

    private func restoreInitialWindowSize(_ window: Window) {
        let startFrame = window.frame

        guard let initialFrame = WindowRecords.getInitialFrame(for: window) else {
            return
        }

        if let screen = NSScreen.screenWithMouse {
            var newWindowFrame = window.frame
            newWindowFrame.size = initialFrame.size
            newWindowFrame = newWindowFrame.pushBottomRightPointInside(screen.frame)
            window.setFrame(newWindowFrame)
        } else {
            window.setSize(initialFrame.size)
        }

        // If the window doesn't contain the cursor, keep the original maxX
        if let cursorLocation = CGEvent.mouseLocation, !window.frame.contains(cursorLocation) {
            var newFrame = window.frame

            newFrame.origin.x = startFrame.maxX - newFrame.width
            window.setFrame(newFrame)

            // If it still doesn't contain the cursor, move the window to be centered with the cursor
            if !newFrame.contains(cursorLocation) {
                newFrame.origin.x = cursorLocation.x - (newFrame.width / 2)
                window.setFrame(newFrame)
            }
        }

        WindowRecords.eraseRecords(for: window)
    }
}
