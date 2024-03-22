//
//  Keybind.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import SwiftUI
import Defaults

struct WindowAction: Codable, Identifiable, Hashable, Equatable, Defaults.Serializable {
    var id: UUID

    init(
        _ direction: WindowDirection,
        keybind: Set<CGKeyCode>,
        name: String? = nil,
        unit: CustomWindowActionUnit? = nil,
        anchor: CustomWindowActionAnchor? = nil,
        width: Double? = nil,
        height: Double? = nil,
        xPoint: Double? = nil,
        yPoint: Double? = nil,
        positionMode: CustomWindowActionPositionMode? = nil,
        sizeMode: CustomWindowActionSizeMode? = nil,
        cycle: [WindowAction]? = nil
    ) {
        self.id = UUID()
        self.direction = direction
        self.keybind = keybind
        self.name = name
        self.unit = unit
        self.anchor = anchor
        self.width = width
        self.height = height
        self.positionMode = positionMode
        self.xPoint = xPoint
        self.yPoint = yPoint
        self.sizeMode = sizeMode
        self.cycle = cycle
    }

    init(_ direction: WindowDirection) {
        self.init(direction, keybind: [])
    }

    init(_ name: String? = nil, _ cycle: [WindowAction], _ keybind: Set<CGKeyCode> = []) {
        self.init(.cycle, keybind: keybind, name: name, cycle: cycle)
    }

    var direction: WindowDirection
    var keybind: Set<CGKeyCode>

    // MARK: CUSTOM KEYBINDS
    var name: String?
    var unit: CustomWindowActionUnit?
    var anchor: CustomWindowActionAnchor?
    var sizeMode: CustomWindowActionSizeMode?
    var width: Double?
    var height: Double?
    var positionMode: CustomWindowActionPositionMode?
    var xPoint: Double?
    var yPoint: Double?

    var cycle: [WindowAction]?

    static func getAction(for keybind: Set<CGKeyCode>) -> WindowAction? {
        for keybinding in Defaults[.keybinds] where keybinding.keybind == keybind {
            return keybinding
        }
        return nil
    }

    // Returns the window frame within the boundaries of (0, 0) to (1, 1)
    // Will be on the screen with mouse if needed.
    func getFrameMultiplyValues(window: Window?) -> CGRect {
        guard self.direction != .cycle else {
            return .zero
        }

        let bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        var result = CGRect.zero

        if let frameMultiplyValues = direction.frameMultiplyValues {
            result.origin.x = bounds.width * frameMultiplyValues.minX
            result.origin.y = bounds.height * frameMultiplyValues.minY
            result.size.width = bounds.width * frameMultiplyValues.width
            result.size.height = bounds.height * frameMultiplyValues.height
        } else if direction == .custom {
            if let sizeMode, sizeMode == .preserveSize {
                guard
                    let screenFrame = NSScreen.screenWithMouse?.visibleFrame,
                    let window = window
                else {
                    return result
                }
                let windowSize = window.size
                result.size.width = windowSize.width / screenFrame.width
                result.size.height = windowSize.height / screenFrame.height
            } else if let sizeMode, sizeMode == .initialSize {
                guard
                    let screenFrame = NSScreen.screenWithMouse?.visibleFrame,
                    let window = window,
                    let initialFrame = WindowRecords.getInitialFrame(for: window)
                else {
                    return result
                }

                result.size.width = initialFrame.size.width / screenFrame.width
                result.size.height = initialFrame.size.height / screenFrame.height
            } else {
                switch unit {
                case .pixels:
                    guard let screenFrame = NSScreen.screenWithMouse?.frame else { return result }
                    result.size.width = (width ?? screenFrame.width) / screenFrame.width
                    result.size.height = (height ?? screenFrame.height) / screenFrame.height
                case .percentage:
                    result.size.width = bounds.width * ((width ?? 0) / 100.0)
                    result.size.height = bounds.height * ((height ?? 0) / 100.0)
                case .none:
                    break
                }
            }

            if let positionMode, positionMode == .coordinates {
                switch unit {
                case .pixels:
                    guard let screenFrame = NSScreen.screenWithMouse?.frame else { return result }
                    result.origin.x = (xPoint ?? screenFrame.width) / screenFrame.width
                    result.origin.y = (yPoint ?? screenFrame.height) / screenFrame.height
                case .percentage:
                    result.origin.x = bounds.width * ((xPoint ?? 0) / 100.0)
                    result.origin.y = bounds.height * ((yPoint ?? 0) / 100.0)
                case .none:
                    break
                }

                // "Crops" the result to be within the screen's bounds
                result = bounds.intersection(result)
            } else {
                switch anchor {
                case .topLeft:
                    break
                case .top:
                    result.origin.x = bounds.midX - result.width / 2
                case .topRight:
                    result.origin.x = bounds.maxX - result.width
                case .right:
                    result.origin.x = bounds.maxX - result.width
                    result.origin.y = bounds.midY - result.height / 2
                case .bottomRight:
                    result.origin.x = bounds.maxX - result.width
                    result.origin.y = bounds.maxY - result.height
                case .bottom:
                    result.origin.x = bounds.midX - result.width / 2
                    result.origin.y = bounds.maxY - result.height
                case .bottomLeft:
                    result.origin.y = bounds.maxY - result.height
                case .left:
                    result.origin.y = bounds.midY - result.height / 2
                case .center:
                    result.origin.x = bounds.midX - result.width / 2
                    result.origin.y = bounds.midY - result.height / 2
                case .macOSCenter:
                    let yOffset = WindowEngine.getMacOSCenterYOffset(result.height, screenHeight: bounds.height)
                    result.origin.x = bounds.midX - result.width / 2
                    result.origin.y = (bounds.midY - result.height / 2) + yOffset
                case .none:
                    break
                }
            }
        }
        return result
    }

    func getEdgesTouchingScreen() -> Edge.Set {
        guard let frameMultiplyValues = direction.frameMultiplyValues else {
            return []
        }

        var result: Edge.Set = []

        if frameMultiplyValues.minX == 0 {
            result.insert(.leading)
        }
        if frameMultiplyValues.maxX == 1 {
            result.insert(.trailing)
        }
        if frameMultiplyValues.minY == 0 {
            result.insert(.top)
        }
        if frameMultiplyValues.maxY == 1 {
            result.insert(.bottom)
        }

        return result
    }
}

// MARK: - Import/Export
extension WindowAction {
    private struct SavedWindowActionFormat: Codable {
        var direction: WindowDirection
        var keybind: Set<CGKeyCode>

        // MARK: CUSTOM KEYBINDS
        var name: String?
        var unit: CustomWindowActionUnit?
        var anchor: CustomWindowActionAnchor?
        var sizeMode: CustomWindowActionSizeMode?
        var width: Double?
        var height: Double?
        var positionMode: CustomWindowActionPositionMode?
        var xPoint: Double?
        var yPoint: Double?

        var cycle: [SavedWindowActionFormat]?

        func convertToWindowAction() -> WindowAction {
            return WindowAction(
                direction,
                keybind: keybind,
                name: name,
                unit: unit,
                anchor: anchor,
                width: width,
                height: height,
                xPoint: xPoint,
                yPoint: yPoint,
                positionMode: positionMode,
                sizeMode: sizeMode,
                cycle: cycle?.map { $0.convertToWindowAction() }
            )
        }
    }

    private func convertToSavedWindowActionFormat() -> SavedWindowActionFormat {
        SavedWindowActionFormat(
            direction: direction,
            keybind: keybind,
            name: name,
            unit: unit,
            anchor: anchor,
            sizeMode: sizeMode,
            width: width,
            height: height,
            positionMode: positionMode,
            xPoint: xPoint,
            yPoint: yPoint,
            cycle: cycle?.map { $0.convertToSavedWindowActionFormat() }
        )
    }

    static func exportPrompt() {
        let keybinds = Defaults[.keybinds]

        if keybinds.isEmpty {
            let alert = NSAlert()
            alert.messageText = "No Keybinds Have Been Set"
            alert.informativeText = "You can't export something that doesn't exist!"
            alert.beginSheetModal(for: NSApplication.shared.mainWindow!)
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let exportKeybinds = keybinds.map {
                $0.convertToSavedWindowActionFormat()
            }

            let keybindsData = try encoder.encode(exportKeybinds)

            if let json = String(data: keybindsData, encoding: .utf8) {
                attemptSave(of: json)
            }
        } catch {
            print("Error encoding keybinds: \(error)")
        }
    }

    private static func attemptSave(of keybindsData: String) {
        let data = keybindsData.data(using: .utf8)

        let savePanel = NSSavePanel()
        if let downloadsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            savePanel.directoryURL = downloadsUrl
        }

        savePanel.title = "Export Keybinds"
        savePanel.nameFieldStringValue = "keybinds"
        savePanel.allowedContentTypes = [.json]

        savePanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { result in
            if result == .OK, let destUrl = savePanel.url {
                DispatchQueue.main.async {
                    do {
                        try data?.write(to: destUrl)
                    } catch {
                        print("Error writing to file: \(error)")
                    }
                }
            }
        }
    }

    static func importPrompt() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Keybinds"
        openPanel.allowedContentTypes = [.json]

        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { result in
            if result == .OK, let selectedFileURL = openPanel.url {
                DispatchQueue.main.async {
                    do {
                        let jsonString = try String(contentsOf: selectedFileURL)
                        importKeybinds(from: jsonString)
                    } catch {
                        print("Error reading file: \(error)")
                    }
                }
            }
        }
    }

    private static func importKeybinds(from jsonString: String) {
        let decoder = JSONDecoder()

        do {
            let keybindsData = jsonString.data(using: .utf8)!
            let importedKeybinds = try decoder.decode([SavedWindowActionFormat].self, from: keybindsData)

            if Defaults[.keybinds].isEmpty {
                for savedKeybind in importedKeybinds {
                    Defaults[.keybinds].append(savedKeybind.convertToWindowAction())
                }
            } else {
                showAlertForImportDecision { decision in
                    switch decision {
                    case .merge:
                        for savedKeybind in importedKeybinds where !Defaults[.keybinds].contains(where: {
                            $0.keybind == savedKeybind.keybind && $0.name == savedKeybind.name
                        }) {
                            Defaults[.keybinds].append(savedKeybind.convertToWindowAction())
                        }

                    case .erase:
                        Defaults[.keybinds] = []

                        for savedKeybind in importedKeybinds {
                            Defaults[.keybinds].append(savedKeybind.convertToWindowAction())
                        }

                    case .cancel:
                        break
                    }
                }
            }
        } catch {
            print("Error decoding keybinds: \(error)")

            let alert = NSAlert()
            alert.messageText = "Error Reading Keybinds"
            alert.informativeText = "Make sure the file you selected is in the correct format."
            alert.beginSheetModal(for: NSApplication.shared.mainWindow!)
        }
    }

    private static func showAlertForImportDecision(completion: @escaping (ImportDecision) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Import Keybinds"
        alert.informativeText = "Do you want to merge or erase existing keybinds?"

        alert.addButton(withTitle: "Merge")
        alert.addButton(withTitle: "Erase")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
            switch response {
            case .alertFirstButtonReturn:  // Merge
                completion(.merge)
            case .alertSecondButtonReturn: // Erase
                completion(.erase)
            default: // Cancel or other cases
                completion(.cancel)
            }
        }
    }

    // Define an enum for the import decision
    enum ImportDecision {
        case merge
        case erase
        case cancel
    }
}
