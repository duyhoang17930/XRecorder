package com.xrecorder.xrecorder.editor

import org.junit.Assert.*
import org.junit.Test

class EditorStorageTest {
    @Test fun reserveIncludesScratchPublishAndMargin() {
        val required=EditorStorage.requiredBytes(4000000,1000000)
        assertTrue(required>32L*1024*1024+1000000)
        EditorStorage.requireSpace(required,required)
        try{EditorStorage.requireSpace(required-1,required);fail("Must reject insufficient storage")}
        catch(expected:IllegalArgumentException){assertTrue(expected.message!!.contains("storage"))}
    }
    @Test fun gifAndLongTimelineEstimatesDoNotOverflow() {
        assertTrue(EditorStorage.requiredBytes(15000000,gif=true,gifEdge=480,gifFps=20)>100L*1024*1024)
        assertTrue(EditorStorage.requiredBytes(86400000000,8000000)>100000000000L)
    }
}
