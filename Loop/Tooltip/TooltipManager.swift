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
//    private let previewController = PreviewController()
    private var dynamicNotch: DynamicNotch?

    private var didForceClose: Bool = false // This is auto-reset once the user stops dragging
    private var draggingWindow: Window?
    static var screenOffset: NSPoint?
    @Published var screen: NSScreen?
    @Published var mouseEvent: NSEvent?
    @Published var currentAction: WindowAction = .init(.noAction)

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
        mouseEvent = event

        if let screenWithMouse = NSScreen.screenWithMouse {
            if screen != screenWithMouse {
                dynamicNotch?.hide()
                currentAction = .init(.noAction)
            }

            self.screen = screenWithMouse

            if TooltipManager.screenOffset == nil {
                TooltipManager.screenOffset = screenWithMouse.frame.origin
            }
        }

        if draggingWindow == nil {
            draggingWindow = WindowEngine.frontmostWindow
        }

        if DynamicNotch.checkIfMouseIsInNotch(), let dynamicNotch, let screen {
            dynamicNotch.show(on: screen)
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
        TooltipManager.screenOffset = nil

        if forceClose {
            didForceClose = true
        }
    }
}
