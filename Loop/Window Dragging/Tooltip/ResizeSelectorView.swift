//
//  ResizeSelectorView.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-22.
//

import SwiftUI

struct ResizeSelectorView: View {
    let padding: CGFloat = 15

    var body: some View {
        HStack(spacing: 0) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ResizeSelectorRectangle(
                        action: .init(.maximize),
                        sectionSize: geo.size
                    )
                }
            }
            .modifier(ResizeSelectorGroup())

            Spacer()
                .frame(width: padding)

            GeometryReader { geo in
                HStack(spacing: 0) {
                    ResizeSelectorRectangle(
                        action: .init(.leftHalf),
                        sectionSize: geo.size
                    )
                    ResizeSelectorRectangle(
                        action: .init(.rightHalf),
                        sectionSize: geo.size
                    )
                }
            }
            .modifier(ResizeSelectorGroup())

            Spacer()
                .frame(width: padding)

            GeometryReader { geo in
                HStack(spacing: 0) {
                    ResizeSelectorRectangle(
                        action: .init(.leftTwoThirds),
                        sectionSize: geo.size
                    )
                    ResizeSelectorRectangle(
                        action: .init(.rightThird),
                        sectionSize: geo.size
                    )
                }
            }
            .modifier(ResizeSelectorGroup())

            Spacer()
                .frame(width: padding)

            GeometryReader { geo in
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ResizeSelectorRectangle(
                            action: .init(.topLeftQuarter),
                            sectionSize: geo.size
                        )
                        ResizeSelectorRectangle(
                            action: .init(.topRightQuarter),
                            sectionSize: geo.size
                        )
                    }
                    HStack(spacing: 0) {
                        ResizeSelectorRectangle(
                            action: .init(.bottomLeftQuarter),
                            sectionSize: geo.size
                        )
                        ResizeSelectorRectangle(
                            action: .init(.bottomRightQuarter),
                            sectionSize: geo.size
                        )
                    }
                }
            }
            .modifier(ResizeSelectorGroup())
        }
        .padding(padding)
    }
}

struct ResizeSelectorGroup: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(-2)
            .aspectRatio(16 / 12, contentMode: .fit)
            .frame(width: 100)
    }
}
