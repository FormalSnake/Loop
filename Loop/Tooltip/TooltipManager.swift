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

    @Published var screen: NSScreen?
    @Published var currentAction: WindowAction = .init(.noAction)
    @Published var directionMap: [UUID: (action: WindowAction, frame: NSRect)] = [:]

    func showIfPossible() {
        if dynamicNotch == nil {
            dynamicNotch = DynamicNotch(
                content: ResizeSelectorView()
                    .environmentObject(self)
            )
        }

        if let screenWithMouse = NSScreen.screenWithMouse {
            if screen != screenWithMouse {
                dynamicNotch?.hide()
                currentAction = .init(.noAction)
            }

            self.screen = screenWithMouse
        }

        if DynamicNotch.checkIfMouseIsInNotch(), let dynamicNotch, let screen, !dynamicNotch.isVisible {
            dynamicNotch.show(on: screen)
        } else {
            if let screen = self.screen {
                if let newAction = self.directionMap.first(where: { map in
                    var frame = map.value.frame.flipY(screen: screen)
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

                    withAnimation(.easeOut(duration: 0.1)) {
                        self.currentAction = newAction.value.action
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.1)) {
                        self.currentAction = .init(.noAction)
                    }
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
