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

    init(action: WindowAction, sectionSize: CGSize) {
        self.action = action
        self.sectionSize = sectionSize
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
                .position(
                    x: geo.frame(in: .local).midX,
                    y: geo.frame(in: .local).midY
                )
                .onChange(of: geo.frame(in: .global)) { _ in
                    tooltipManager.directionMap[action] = geo.frame(in: .global)
                }
        }
        .padding(3)
        .frame(
            width: sectionSize.width * (action.direction.frameMultiplyValues?.width ?? .zero),
            height: sectionSize.height * (action.direction.frameMultiplyValues?.height ?? .zero)
        )
    }
}
