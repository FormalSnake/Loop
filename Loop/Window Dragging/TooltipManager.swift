//
//  TooltipManager.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-06.
//

import Defaults
import DynamicNotchKit
import SwiftUI

class TooltipManager: ObservableObject {
    private var dynamicNotch: DynamicNotch?
    private let previewController = WindowDragManager.previewController

    @Published var screen: NSScreen?
    @Published var currentAction: WindowAction = .init(.noAction)
    @Published var directionMap: [WindowAction: NSRect] = [:]
    var isVisible: Bool {
        dynamicNotch?.isVisible ?? false
    }

    func showIfPossible() {
        if dynamicNotch == nil {
            dynamicNotch = DynamicNotch(
                content: ResizeSelectorView()
                    .environmentObject(self)
            )
        }

        if let screenWithMouse = NSScreen.screenWithMouse,
           screen != screenWithMouse {
            dynamicNotch?.hide()
            previewController.close()
            currentAction = .init(.noAction)
            directionMap = [:]

            screen = screenWithMouse
        }

        guard let screen else {
            return
        }

        if DynamicNotch.checkIfMouseIsInNotch(), let dynamicNotch, !dynamicNotch.isVisible {
            dynamicNotch.show(on: screen)
        } else {
            let oldAction = currentAction

            if let newAction = directionMap.first(where: { map in
                var frame = map.value.flipY(screen: screen)
                frame.origin.x += screen.frame.minX
                frame.origin.y += screen.frame.minY

                return frame.contains(NSEvent.mouseLocation)
            }) {
                if Defaults[.hapticFeedback] {
                    NSHapticFeedbackManager.defaultPerformer.perform(
                        NSHapticFeedbackManager.FeedbackPattern.alignment,
                        performanceTime: NSHapticFeedbackManager.PerformanceTime.now
                    )
                }

                previewController.open(screen: screen, window: nil)

                withAnimation(.easeOut(duration: 0.1)) {
                    self.currentAction = newAction.key
                }
            } else {
                withAnimation(.easeOut(duration: 0.1)) {
                    self.currentAction = .init(.noAction)
                }
            }

            if oldAction.direction != currentAction.direction {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name.updateUIDirection,
                        object: nil,
                        userInfo: ["action": self.currentAction]
                    )
                }
            }
        }
    }

    func closeAndResize(_ window: Window) {
        dynamicNotch?.hide()

        if let screen {
            WindowEngine.resize(window, to: currentAction, on: screen)
        }

        screen = nil
        currentAction = .init(.noAction)
        directionMap = [:]
    }
}
