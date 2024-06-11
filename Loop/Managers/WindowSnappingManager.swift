//
//  WindowSnappingManager.swift
//  Loop
//
//  Created by Kai Azim on 2024-06-11.
//

import Cocoa
import Defaults

class WindowSnappingManager {
    private var direction: WindowDirection = .noAction
    private let previewController = PreviewController()

    func getWindowSnapDirection() {
        guard let screen = NSScreen.screenWithMouse else {
            return
        }
        let mousePosition = NSEvent.mouseLocation.flipY(maxY: screen.frame.maxY)
        let screenFrame = screen.frame.flipY(maxY: screen.frame.maxY)

        previewController.setScreen(to: screen)

        let insets: CGFloat = 2
        let topInset = screen.menubarHeight / 2
        var ignoredFrame = screenFrame

        ignoredFrame.origin.x += insets
        ignoredFrame.size.width -= insets * 2
        ignoredFrame.origin.y += topInset
        ignoredFrame.size.height -= insets + topInset

        let oldDirection = direction

        if !ignoredFrame.contains(mousePosition) {
            direction = WindowDirection.processSnap(
                mouseLocation: mousePosition,
                currentDirection: direction,
                screenFrame: screenFrame,
                ignoredFrame: ignoredFrame
            )

            print("Window snapping direction changed: \(direction)")

            previewController.open(screen: screen, window: nil)

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name.updateUIDirection,
                    object: nil,
                    userInfo: ["action": WindowAction(self.direction)]
                )
            }
        } else {
            reset()
        }

        if direction != oldDirection {
            if Defaults[.hapticFeedback] {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    NSHapticFeedbackManager.FeedbackPattern.alignment,
                    performanceTime: NSHapticFeedbackManager.PerformanceTime.now
                )
            }
        }
    }

    func reset() {
        DispatchQueue.main.async {
            self.direction = .noAction
            self.previewController.close()
        }
    }

    func closeAndResize(_ window: Window) {
        guard let screen = NSScreen.screenWithMouse else {
            return
        }

        DispatchQueue.main.async {
            WindowEngine.resize(window, to: .init(self.direction), on: screen)
            self.direction = .noAction
        }
    }
}
