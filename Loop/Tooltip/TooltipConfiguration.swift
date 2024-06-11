//
//  TooltipConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-07.
//

import Defaults
import SwiftUI

enum TooltipConfiguration: Int, _DefaultsSerializable, CaseIterable, Identifiable {
    var id: Self { self }

    case off = 0
    case notch = 1

    var name: String {
        switch self {
        case .off: "Off"
        case .notch: "Notch"
        }
    }
}
