package com.xrecorder.xrecorder.recording

import org.junit.Assert.*
import org.junit.Test

class DrawingStrokeEngineTest {

    @Test
    fun clampWidthValidatesNormalAndBoundaryValues() {
        assertEquals(8.0f, DrawingStrokeEngine.clampWidth(8.0f), 0.001f)
        assertEquals(DrawingStrokeEngine.MIN_STROKE_WIDTH, DrawingStrokeEngine.clampWidth(0.5f), 0.001f)
        assertEquals(DrawingStrokeEngine.DEFAULT_STROKE_WIDTH, DrawingStrokeEngine.clampWidth(-10f), 0.001f)
        assertEquals(DrawingStrokeEngine.MAX_STROKE_WIDTH, DrawingStrokeEngine.clampWidth(100f), 0.001f)
        assertEquals(DrawingStrokeEngine.DEFAULT_STROKE_WIDTH, DrawingStrokeEngine.clampWidth(null), 0.001f)
        assertEquals(DrawingStrokeEngine.DEFAULT_STROKE_WIDTH, DrawingStrokeEngine.clampWidth(Float.NaN), 0.001f)
    }

    @Test
    fun clampColorEnsuresOpaqueAlpha() {
        // Standard ARGB
        val orange = 0xFFFF7847.toInt()
        assertEquals(orange, DrawingStrokeEngine.clampColor(orange))

        // RGB only (alpha is 0) -> should be made fully opaque
        val rgbOnly = 0x00FF7847
        val expectedOpaque = 0xFFFF7847.toInt()
        assertEquals(expectedOpaque, DrawingStrokeEngine.clampColor(rgbOnly))

        // Null fallback
        assertEquals(DrawingStrokeEngine.DEFAULT_COLOR, DrawingStrokeEngine.clampColor(null))
    }

    @Test
    fun resolveWindowFlagsTogglesTouchableState() {
        val drawingFlags = DrawingStrokeEngine.resolveWindowFlags(isDrawingMode = true)
        // Must NOT have FLAG_NOT_TOUCHABLE when drawing is active
        assertEquals(0, drawingFlags and DrawingStrokeEngine.FLAG_NOT_TOUCHABLE)
        assertNotEquals(0, drawingFlags and DrawingStrokeEngine.FLAG_NOT_FOCUSABLE)

        val passthroughFlags = DrawingStrokeEngine.resolveWindowFlags(isDrawingMode = false)
        // MUST have FLAG_NOT_TOUCHABLE when drawing is inactive so touches pass through
        assertNotEquals(0, passthroughFlags and DrawingStrokeEngine.FLAG_NOT_TOUCHABLE)
        assertNotEquals(0, passthroughFlags and DrawingStrokeEngine.FLAG_NOT_FOCUSABLE)
    }

    @Test
    fun sessionRejectsDrawingWhenModeDisabled() {
        val session = DrawingStrokeEngine.Session()
        assertFalse(session.isDrawingMode)

        // Starting or adding points fails when drawing mode is off
        assertFalse(session.startStroke(100f, 100f))
        assertFalse(session.addPoint(110f, 110f))
        assertNull(session.endStroke())
        assertEquals(0, session.strokeCount)
    }

    @Test
    fun sessionAccumulatesStrokesWhenModeEnabled() {
        val session = DrawingStrokeEngine.Session(currentColor = 0xFFFF0000.toInt(), currentWidth = 12f)
        session.setDrawingMode(true)
        assertTrue(session.isDrawingMode)

        // Stroke 1: 3 points
        assertTrue(session.startStroke(10f, 10f))
        assertTrue(session.addPoint(20f, 20f))
        assertTrue(session.addPoint(30f, 30f))
        val stroke1 = session.endStroke()

        assertNotNull(stroke1)
        assertEquals(3, stroke1!!.points.size)
        assertEquals(0xFFFF0000.toInt(), stroke1.color)
        assertEquals(12f, stroke1.width, 0.001f)
        assertEquals(1, session.strokeCount)

        // Stroke 2: 2 points
        session.setStyle(color = 0xFF00FF00.toInt(), width = 6f)
        assertTrue(session.startStroke(50f, 50f))
        assertTrue(session.addPoint(60f, 60f))
        val stroke2 = session.endStroke()

        assertNotNull(stroke2)
        assertEquals(2, stroke2!!.points.size)
        assertEquals(0xFF00FF00.toInt(), stroke2.color)
        assertEquals(6f, stroke2.width, 0.001f)
        assertEquals(2, session.strokeCount)
    }

    @Test
    fun undoRemovesStrokesInLifoOrder() {
        val session = DrawingStrokeEngine.Session()
        session.setDrawingMode(true)

        // Empty session cannot undo
        assertFalse(session.canUndo)
        assertFalse(session.undo())

        // Add 2 strokes
        session.startStroke(10f, 10f); session.addPoint(20f, 20f); session.endStroke()
        session.startStroke(30f, 30f); session.addPoint(40f, 40f); session.endStroke()
        assertEquals(2, session.strokeCount)
        assertTrue(session.canUndo)

        // Undo stroke 2
        assertTrue(session.undo())
        assertEquals(1, session.strokeCount)
        assertEquals(10f, session.strokes[0].points[0].x, 0.001f)

        // Undo stroke 1
        assertTrue(session.undo())
        assertEquals(0, session.strokeCount)
        assertFalse(session.canUndo)

        // Further undo fails
        assertFalse(session.undo())
    }

    @Test
    fun clearResetsAllStrokesAndActivePoints() {
        val session = DrawingStrokeEngine.Session()
        session.setDrawingMode(true)

        session.startStroke(10f, 10f); session.addPoint(20f, 20f); session.endStroke()
        session.startStroke(30f, 30f); session.addPoint(40f, 40f); session.endStroke()
        session.startStroke(50f, 50f) // in-progress stroke

        assertEquals(2, session.strokeCount)
        val cleared = session.clear()
        assertEquals(2, cleared)
        assertEquals(0, session.strokeCount)
        assertEquals(0, session.activeStrokePoints.size)
        assertFalse(session.canUndo)
    }

    @Test
    fun rotationTransformationProportionallyRemapsCoordinates() {
        val portraitW = 1080
        val portraitH = 2400
        val landscapeW = 2400
        val landscapeH = 1080

        val p1 = DrawingStrokeEngine.Point(540f, 1200f) // exact center
        val p2 = DrawingStrokeEngine.Point(1080f, 2400f) // bottom-right corner

        val points = listOf(p1, p2)
        val transformed = DrawingStrokeEngine.transformPointsOnRotation(
            points, portraitW, portraitH, landscapeW, landscapeH
        )

        assertEquals(2, transformed.size)
        // Center should map to new center (1200, 540)
        assertEquals(1200f, transformed[0].x, 0.01f)
        assertEquals(540f, transformed[0].y, 0.01f)

        // Bottom-right corner should map to new bottom-right (2400, 1080)
        assertEquals(2400f, transformed[1].x, 0.01f)
        assertEquals(1080f, transformed[1].y, 0.01f)
    }

    @Test
    fun canAcceptActionValidatesStatesAndEnding() {
        // Valid when recording or paused and not ending
        for (action in listOf("setDrawingEnabled", "clearDrawing", "undoDrawing", "setDrawingStyle", "getDrawingState")) {
            assertTrue(DrawingStrokeEngine.canAcceptAction(action, isEnding = false, currentState = "recording"))
            assertTrue(DrawingStrokeEngine.canAcceptAction(action, isEnding = false, currentState = "paused"))

            // Reject when ending
            assertFalse(DrawingStrokeEngine.canAcceptAction(action, isEnding = true, currentState = "recording"))

            // Reject in other states
            for (s in listOf("idle", "countdown", "stopping", "finalizing", "completed", "failed")) {
                assertFalse(DrawingStrokeEngine.canAcceptAction(action, isEnding = false, currentState = s))
            }
        }
    }

    @Test
    fun sessionSnapshotCapturesEngineStateAccurately() {
        val session = DrawingStrokeEngine.Session(currentColor = 0xFF123456.toInt(), currentWidth = 14f)
        session.setDrawingMode(true)
        session.startStroke(5f, 5f); session.addPoint(15f, 15f); session.endStroke()

        val snap = session.snapshot()
        assertTrue(snap.isDrawingMode)
        assertEquals(1, snap.strokeCount)
        assertTrue(snap.canUndo)
        assertEquals(0xFF123456.toInt(), snap.currentColor)
        assertEquals(14f, snap.currentWidth, 0.001f)
    }
}
