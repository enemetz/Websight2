//
//  ToolbarLayoutTests.swift
//  Websight-2Tests
//
//  Tests for History/Settings button placement on iPhone Duo vs. other devices.
//

import Testing
import SwiftUI
@testable import websight

@Suite("Toolbar Layout Tests")
struct ToolbarLayoutTests {

    // MARK: Vertical bar detection

    @Test("No vertical edge means no vertical bar")
    func noEdge() {
        let edge: VerticalEdge? = nil
        #expect(ToolbarLayout.hasVerticalBar(edge: edge) == false)
    }

    @Test("Top edge counts as a vertical bar")
    func topEdge() {
        #expect(ToolbarLayout.hasVerticalBar(edge: VerticalEdge.top) == true)
    }

    @Test("Bottom edge counts as a vertical bar")
    func bottomEdge() {
        #expect(ToolbarLayout.hasVerticalBar(edge: VerticalEdge.bottom) == true)
    }

    @Test("Horizontal edges count as a vertical bar")
    func horizontalEdges() {
        #expect(ToolbarLayout.hasVerticalBar(edge: Edge.leading) == true)
        #expect(ToolbarLayout.hasVerticalBar(edge: Edge.trailing) == true)
    }

    // MARK: Button position

    @Test("Buttons use bottom bar when a vertical bar is present")
    func bottomBarWhenVertical() {
        #expect(ToolbarLayout.position(hasVerticalBar: true) == .bottomBar)
    }

    @Test("Buttons use automatic placement otherwise")
    func automaticWhenNotVertical() {
        #expect(ToolbarLayout.position(hasVerticalBar: false) == .automatic)
    }

    @Test("Edge detection flows through to button position")
    func edgeToPosition() {
        let none: VerticalEdge? = nil
        #expect(ToolbarLayout.position(hasVerticalBar: ToolbarLayout.hasVerticalBar(edge: none)) == .automatic)
        #expect(ToolbarLayout.position(hasVerticalBar: ToolbarLayout.hasVerticalBar(edge: VerticalEdge.bottom)) == .bottomBar)
    }

    // MARK: Placement mapping

    @Test("Placement can be built for both states")
    func placementMapping() {
        // ToolbarItemPlacement isn't reliably Equatable, so just verify it resolves
        // without crashing; the decision itself is covered by `position(hasVerticalBar:)`.
        _ = ToolbarLayout.placement(hasVerticalBar: true)
        _ = ToolbarLayout.placement(hasVerticalBar: false)
    }
}
