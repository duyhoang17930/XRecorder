package com.xrecorder.xrecorder.recording

object RegionCropGeometry {
    data class CropRect(
        val x: Int,
        val y: Int,
        val width: Int,
        val height: Int
    )

    data class NormalizedCrop(
        val left: Float,
        val top: Float,
        val right: Float,
        val bottom: Float
    )

    fun dpToPx(dp: Float, density: Float): Int =
        (dp * density + 0.5f).toInt()

    fun pxToDp(px: Int, density: Float): Float =
        if (density > 0f) px / density else px.toFloat()

    /**
     * Sanitizes and bounds a region crop against the physical display dimensions.
     * Enforces even width and height alignment (required by MediaCodec H.264/H.265)
     * and a minimum dimension limit.
     */
    fun sanitizeRegion(
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        displayWidth: Int,
        displayHeight: Int,
        minDimension: Int = 160,
        alignment: Int = 2
    ): CropRect? {
        if (displayWidth <= 0 || displayHeight <= 0) return null
        if (width <= 0 || height <= 0) return null
        if (x >= displayWidth || y >= displayHeight || x + width <= 0 || y + height <= 0) return null

        val clampedX = maxOf(0, x)
        val clampedY = maxOf(0, y)
        val clampedRight = minOf(displayWidth, x + width)
        val clampedBottom = minOf(displayHeight, y + height)

        val clampedWidth = clampedRight - clampedX
        val clampedHeight = clampedBottom - clampedY

        if (clampedWidth <= 0 || clampedHeight <= 0) return null

        val alignFactor = maxOf(1, alignment)
        val alignedWidth = (clampedWidth / alignFactor) * alignFactor
        val alignedHeight = (clampedHeight / alignFactor) * alignFactor

        if (alignedWidth < minDimension || alignedHeight < minDimension) return null

        return CropRect(clampedX, clampedY, alignedWidth, alignedHeight)
    }

    /**
     * Convenience method to convert Flutter DP coordinates to physical pixels
     * and sanitize against the display bounds.
     */
    fun fromDp(
        dpX: Float,
        dpY: Float,
        dpWidth: Float,
        dpHeight: Float,
        density: Float,
        displayWidth: Int,
        displayHeight: Int,
        minDimension: Int = 160,
        alignment: Int = 2
    ): CropRect? {
        if (density <= 0f) return null
        val pxX = dpToPx(dpX, density)
        val pxY = dpToPx(dpY, density)
        val pxWidth = dpToPx(dpWidth, density)
        val pxHeight = dpToPx(dpHeight, density)
        return sanitizeRegion(pxX, pxY, pxWidth, pxHeight, displayWidth, displayHeight, minDimension, alignment)
    }

    /**
     * Computes normalized UV coordinates in [0.0, 1.0] for compositor texture blitting.
     */
    fun normalizedCrop(rect: CropRect, displayWidth: Int, displayHeight: Int): NormalizedCrop {
        require(displayWidth > 0 && displayHeight > 0) { "Display dimensions must be positive" }
        return NormalizedCrop(
            left = rect.x.toFloat() / displayWidth,
            top = rect.y.toFloat() / displayHeight,
            right = (rect.x + rect.width).toFloat() / displayWidth,
            bottom = (rect.y + rect.height).toFloat() / displayHeight
        )
    }

    fun aspectRatio(rect: CropRect): Double =
        if (rect.height > 0) rect.width.toDouble() / rect.height.toDouble() else 0.0

    fun fitsDisplay(rect: CropRect, displayWidth: Int, displayHeight: Int): Boolean =
        rect.x >= 0 && rect.y >= 0 &&
        rect.width > 0 && rect.height > 0 &&
        rect.x + rect.width <= displayWidth &&
        rect.y + rect.height <= displayHeight
}
