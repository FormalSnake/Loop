//
//  ResizeSelectorRectangle.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-22.
//

import Defaults
import SwiftUI

struct ResizeSelectorRectangle: View {
    @EnvironmentObject var tooltipManager: TooltipManager

    let cornerRadius: CGFloat = 5

    let activeColor: NSColor = .controlBackgroundColor
    let inactiveColor: NSColor = .controlBackgroundColor

    let action: WindowAction
    let sectionSize: CGSize
    let windowHeight: CGFloat

    init(action: WindowAction, sectionSize: CGSize, windowHeight: CGFloat) {
        self.action = action
        self.sectionSize = sectionSize
        self.windowHeight = windowHeight
    }

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: cornerRadius)
                .foregroundStyle(
                    Color.secondary.opacity(
                        action.direction == tooltipManager.currentAction.direction ? 0.3 : 0.1
                    )
                )
                .overlay {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(lineWidth: 1.5)
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                }
                .padding(3)
                .position(x: geo.frame(in: .local).midX, y: geo.frame(in: .local).midY)
                .onChange(of: tooltipManager.mouseEvent) { _ in
                    guard
                        let offset = TooltipManager.screenOffset,
                        tooltipManager.currentAction.direction != self.action.direction
                    else {
                        return
                    }

                    var frame = geo.frame(in: .global)
                    guard let screen = tooltipManager.screen else { return }
                    frame = frame.flipY(maxY: screen.frame.maxY)

                    frame.origin.x += offset.x
                    frame.origin.y += offset.y

                    if frame.contains(NSEvent.mouseLocation) {
                        Notification.Name.updateUIDirection.post(userInfo: ["action": action])

                        if Defaults[.hapticFeedback] {
                            NSHapticFeedbackManager.defaultPerformer.perform(
                                NSHapticFeedbackManager.FeedbackPattern.alignment,
                                performanceTime: NSHapticFeedbackManager.PerformanceTime.now
                            )
                        }

                        withAnimation(.easeOut(duration: 0.1)) {
                            tooltipManager.currentAction = action
                        }
                    }
                }
        }
        .frame(
            width: sectionSize.width * (action.direction.frameMultiplyValues?.width ?? .zero),
            height: sectionSize.height * (action.direction.frameMultiplyValues?.height ?? .zero)
        )
    }
}
