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
    private var eventMonitor: EventMonitor?
    private var dynamicNotch: DynamicNotch?

    private var didForceClose: Bool = false // This is auto-reset once the user stops dragging
    private var draggingWindow: Window?

    @Published var screen: NSScreen?
    @Published var currentAction: WindowAction = .init(.noAction)
    @Published var directionMap: [UUID: (action: WindowAction, frame: NSRect)] = [:]

    func start() {
        dynamicNotch = DynamicNotch(
            content: ResizeSelectorView()
                .environmentObject(self)
        )

        eventMonitor = NSEventMonitor(
            scope: .global,
            eventMask: [.leftMouseDragged, .leftMouseUp, .keyDown]
        ) { event in
            if event.type == .leftMouseDragged {
                self.leftMouseDragged(event: event)
            }

            if event.type == .leftMouseUp {
                self.leftMouseUp()
            }

            if event.type == .keyDown,
               event.keyCode == .kVK_Escape {
                self.close(forceClose: true)
            }
        }

        eventMonitor!.start()
    }

    func leftMouseDragged(event: NSEvent) {
        guard Defaults[.tooltipConfiguration] != .off, !didForceClose else { return }

        if let screenWithMouse = NSScreen.screenWithMouse {
            if screen != screenWithMouse {
                dynamicNotch?.hide()
                currentAction = .init(.noAction)
            }

            self.screen = screenWithMouse
        }

        if draggingWindow == nil {
            draggingWindow = WindowEngine.frontmostWindow
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

    private func hasWindowMoved(_ windowFrame: CGRect, _ initialFrame: CGRect) -> Bool {
        !initialFrame.topLeftPoint.approximatelyEqual(to: windowFrame.topLeftPoint, tolerance: 50) &&
            !initialFrame.topRightPoint.approximatelyEqual(to: windowFrame.topRightPoint, tolerance: 50) &&
            !initialFrame.bottomLeftPoint.approximatelyEqual(to: windowFrame.bottomLeftPoint, tolerance: 50) &&
            !initialFrame.bottomRightPoint.approximatelyEqual(to: windowFrame.bottomRightPoint, tolerance: 50)
    }

    func leftMouseUp() {
        let configuration = Defaults[.tooltipConfiguration]
        guard configuration != .off else { return }

        let shouldResize = dynamicNotch?.isVisible ?? false
        close(forceClose: !shouldResize)
        didForceClose = false
    }

    private func close(forceClose: Bool = false) {
        dynamicNotch?.hide()

        if !forceClose, let window = draggingWindow, let screen {
            WindowEngine.resize(window, to: currentAction, on: screen)
        }

        screen = nil
        currentAction = .init(.noAction)
        draggingWindow = nil

        if forceClose {
            didForceClose = true
        }
    }
}
