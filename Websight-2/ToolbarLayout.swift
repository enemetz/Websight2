//
//  ToolbarLayout.swift
//  Websight-2
//
//  Decides where the History / Settings buttons go. On devices with a vertical
//  toolbar edge (e.g. iPhone Duo) they move to the bottom bar; otherwise they
//  use the system's automatic placement.
//

import SwiftUI

nonisolated enum ToolbarLayout {
    enum ButtonPosition: Equatable {
        case bottomBar
        case automatic
    }

    /// Whether a vertical toolbar edge is present. Any non-nil edge counts.
    static func hasVerticalBar<Edge>(edge: Edge?) -> Bool {
        edge != nil
    }

    static func position(hasVerticalBar: Bool) -> ButtonPosition {
        hasVerticalBar ? .bottomBar : .automatic
    }

    static func placement(hasVerticalBar: Bool) -> ToolbarItemPlacement {
        switch position(hasVerticalBar: hasVerticalBar) {
        case .bottomBar: return .bottomBar
        case .automatic: return .automatic
        }
    }
}
