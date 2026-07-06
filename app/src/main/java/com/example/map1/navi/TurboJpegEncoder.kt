package com.example.map1.navi

import android.graphics.Bitmap
import java.nio.ByteBuffer

/** libjpeg-turbo based JPEG encoder for ARGB_8888 bitmaps. */
object TurboJpegEncoder {
    private val available = runCatching { System.loadLibrary("navi_jpeg") }.isSuccess

    fun encode(bitmap: Bitmap, quality: Int): ByteArray? {
        if (!available) return null
        return nativeEncode(bitmap, quality)
    }

    fun encodeRgba(buffer: ByteBuffer, width: Int, height: Int, rowStride: Int, quality: Int): ByteArray? {
        if (!available) return null
        return nativeEncodeRgba(buffer, width, height, rowStride, quality)
    }

    private external fun nativeEncode(bitmap: Bitmap, quality: Int): ByteArray?

    private external fun nativeEncodeRgba(
        buffer: ByteBuffer,
        width: Int,
        height: Int,
        rowStride: Int,
        quality: Int,
    ): ByteArray?
}
