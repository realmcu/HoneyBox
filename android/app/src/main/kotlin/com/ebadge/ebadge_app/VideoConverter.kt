package com.ebadge.ebadge_app

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.Rect
import android.graphics.RectF
import android.media.MediaMetadataRetriever
import android.os.Build
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.floor

/**
 * Video / GIF → device-playable AVI(CVID). The Android counterpart of the
 * miniprogram's `utils/video-converter.js`. Frame extraction is native:
 * video uses MediaMetadataRetriever (time-based), GIF uses android.graphics.Movie
 * (LZW + frame disposal handled by the platform), instead of wx.createVideoDecoder
 * / a JS GIF decoder:
 *
 *   1) read source width/height/duration/fps;
 *   2) sample frames at t_j = j / outFps seconds (j = 0 .. estTotal-1) — this
 *      reproduces the miniprogram's fractional frame-step timing, since its
 *      captured frame j lands at native index j·(nativeFps/targetFps), i.e.
 *      time j/targetFps ≈ j/outFps;
 *   3) crop/resize each frame to the target resolution (matches resizeFrame);
 *      GIF frames are first composited onto an opaque [bgColor] so transparent
 *      pixels get a user-chosen background instead of the miniprogram's black;
 *   4) Cinepak-encode (first frame key, rest inter) and mux to AVI.
 *
 * outFps = min(targetFps, nativeFps); estTotal = floor(duration · outFps),
 * capped at maxFrames. width/height must be multiples of 4 (Cinepak).
 */
class VideoConverter {

    fun interface Progress {
        fun onProgress(done: Int, total: Int)
    }

    class Cancelled : RuntimeException("cancelled")

    class Result(
        val avi: ByteArray,
        val width: Int,
        val height: Int,
        val frameCount: Int,
        val fps: Double,
    )

    class Thumb(val png: ByteArray, val width: Int, val height: Int, val isGif: Boolean)

    /** A short set of downscaled PNG frames + the real-time interval between them. */
    class PreviewClip(val frames: List<ByteArray>, val intervalMs: Int)

    private val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG).apply {
        isFilterBitmap = true
    }

    // Detect GIF by the "GIF" magic (don't trust the extension — album pickers
    // sometimes hand back a .jpg name for an animated source, and vice-versa).
    private fun isGif(path: String): Boolean {
        return try {
            File(path).inputStream().use { s ->
                val h = ByteArray(3)
                s.read(h) == 3 && h[0].toInt() == 0x47 && h[1].toInt() == 0x49 &&
                    h[2].toInt() == 0x46
            }
        } catch (_: Exception) {
            false
        }
    }

    // ── first frame for the crop-preview base ────────────────────────────────
    fun thumbnail(path: String): Thumb {
        if (isGif(path)) return gifThumbnail(path)
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            val bmp = r.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                ?: r.getFrameAtTime(-1)
                ?: throw RuntimeException("无法读取视频首帧")
            val out = ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
            val w = bmp.width
            val h = bmp.height
            bmp.recycle()
            return Thumb(out.toByteArray(), w, h, false)
        } finally {
            releaseRetriever(r)
        }
    }

    // GIF preview: render the first frame with transparency PRESERVED (drawn on
    // a cleared bitmap) so the Flutter side can composite it live over the
    // user-selected background color. PNG keeps the alpha channel.
    // Movie is deprecated but is the only built-in GIF *frame extractor*
    // (AnimatedImageDrawable only plays), so the deprecation is intentional.
    @Suppress("DEPRECATION")
    private fun gifThumbnail(path: String): Thumb {
        val bytes = File(path).readBytes()
        val movie = android.graphics.Movie.decodeByteArray(bytes, 0, bytes.size)
            ?: throw RuntimeException("无法解析 GIF")
        val w = movie.width()
        val h = movie.height()
        if (w <= 0 || h <= 0) throw RuntimeException("GIF 尺寸无效")
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        movie.setTime(0)
        movie.draw(c, 0f, 0f)
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        bmp.recycle()
        return Thumb(out.toByteArray(), w, h, true)
    }

    // ── playback-preview frames (video / GIF) ────────────────────────────────
    // A short, downscaled set of frames the Flutter side cycles to preview the
    // clip's motion inside the framing viewport (before conversion). Frames keep
    // the source aspect ratio so the on-screen contain-fit is identical to the
    // still thumbnail; GIF frames keep their alpha so the chosen background shows
    // through transparent pixels live (same as the thumbnail).
    fun previewFrames(path: String, maxCount: Int, maxEdge: Int): PreviewClip {
        if (isGif(path)) return gifPreviewFrames(path, maxCount, maxEdge)
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            val durationMs =
                r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val durationSec = durationMs / 1000.0

            var nativeFps = 25.0
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val fc = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT)
                    ?.toIntOrNull() ?: 0
                if (fc > 0 && durationSec > 0) nativeFps = fc / durationSec
            }
            if (nativeFps <= 0) nativeFps = 25.0

            val previewFps = minOf(12.0, nativeFps)
            var count = if (durationSec > 0) floor(durationSec * previewFps).toInt() else 1
            if (count < 1) count = 1
            if (count > maxCount) count = maxCount

            val frames = ArrayList<ByteArray>(count)
            for (j in 0 until count) {
                val tUs = if (durationMs > 0) Math.round(durationMs * 1000.0 * j / count) else 0L
                val bmp = r.getFrameAtTime(tUs, MediaMetadataRetriever.OPTION_CLOSEST)
                    ?: r.getFrameAtTime(tUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    ?: continue
                frames.add(scaledPng(bmp, maxEdge))
                bmp.recycle()
            }
            if (frames.isEmpty()) {
                val bmp = r.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    ?: r.getFrameAtTime(-1)
                if (bmp != null) {
                    frames.add(scaledPng(bmp, maxEdge))
                    bmp.recycle()
                }
            }
            if (frames.isEmpty()) throw RuntimeException("无法读取视频帧")
            val interval = if (durationMs > 0) (durationMs / frames.size).toInt().coerceIn(50, 200) else 100
            return PreviewClip(frames, interval)
        } finally {
            releaseRetriever(r)
        }
    }

    @Suppress("DEPRECATION")
    private fun gifPreviewFrames(path: String, maxCount: Int, maxEdge: Int): PreviewClip {
        val bytes = File(path).readBytes()
        val movie = android.graphics.Movie.decodeByteArray(bytes, 0, bytes.size)
            ?: throw RuntimeException("无法解析 GIF")
        val gw = movie.width()
        val gh = movie.height()
        if (gw <= 0 || gh <= 0) throw RuntimeException("GIF 尺寸无效")

        val durationMs = movie.duration()
        val frameCount = countGifFrames(bytes)
        var count = if (frameCount > 0) frameCount else 12
        if (durationMs <= 0) count = 1 // static GIF → single frame
        if (count > maxCount) count = maxCount
        if (count < 1) count = 1

        val src = Bitmap.createBitmap(gw, gh, Bitmap.Config.ARGB_8888)
        val c = Canvas(src)
        val frames = ArrayList<ByteArray>(count)
        try {
            for (j in 0 until count) {
                var tMs = if (durationMs > 0) Math.round(durationMs.toDouble() * j / count).toInt() else 0
                if (durationMs > 0 && tMs >= durationMs) tMs = durationMs - 1
                c.drawColor(0, PorterDuff.Mode.CLEAR) // keep transparency for live bg compositing
                movie.setTime(tMs)
                movie.draw(c, 0f, 0f)
                frames.add(scaledPng(src, maxEdge))
            }
        } finally {
            src.recycle()
        }
        val interval = if (durationMs > 0) (durationMs / count).coerceIn(50, 200) else 100
        return PreviewClip(frames, interval)
    }

    // Proportionally downscale [src] so its longest edge ≤ [maxEdge], then
    // PNG-encode (alpha preserved when the source bitmap has it).
    private fun scaledPng(src: Bitmap, maxEdge: Int): ByteArray {
        val w = src.width
        val h = src.height
        val scale = minOf(1.0, maxEdge.toDouble() / maxOf(w, h))
        val dstW = maxOf(1, Math.round(w * scale).toInt())
        val dstH = maxOf(1, Math.round(h * scale).toInt())
        val scaled = if (dstW == w && dstH == h) src else Bitmap.createScaledBitmap(src, dstW, dstH, true)
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.PNG, 100, out)
        if (scaled !== src) scaled.recycle()
        return out.toByteArray()
    }

    // Count GIF image frames by walking the block structure (no LZW decode) so
    // we can derive nativeFps and avoid over-sampling low-rate GIFs. Defensive:
    // returns 0 on any parse hiccup (→ nativeFps falls back to 10).
    private fun countGifFrames(b: ByteArray): Int {
        return try {
            if (b.size < 13) return 0
            var p = 6 // skip "GIF87a" / "GIF89a"
            val packed = b[p + 4].toInt() and 0xFF
            p += 7 // logical screen descriptor
            if (packed and 0x80 != 0) p += (2 shl (packed and 0x07)) * 3 // global color table
            var count = 0
            loop@ while (p < b.size) {
                val block = b[p].toInt() and 0xFF
                p++
                when (block) {
                    0x3B -> break@loop // trailer
                    0x21 -> { // extension: skip label + sub-blocks
                        p++
                        p = skipSubBlocks(b, p)
                    }
                    0x2C -> { // image descriptor → one frame
                        if (p + 9 > b.size) break@loop
                        val imgPacked = b[p + 8].toInt() and 0xFF
                        p += 9
                        if (imgPacked and 0x80 != 0) p += (2 shl (imgPacked and 0x07)) * 3
                        p++ // LZW min code size
                        p = skipSubBlocks(b, p)
                        count++
                    }
                    else -> break@loop
                }
            }
            count
        } catch (_: Exception) {
            0
        }
    }

    private fun skipSubBlocks(b: ByteArray, start: Int): Int {
        var p = start
        while (p < b.size) {
            val len = b[p].toInt() and 0xFF
            p++
            if (len == 0) break
            p += len
        }
        return p
    }

    // ── centered cover crop (keep target aspect, trim overflow) ──────────────
    private fun coverCrop(srcW: Int, srcH: Int, dstW: Int, dstH: Int): IntArray {
        val targetAR = dstW.toDouble() / dstH
        val srcAR = srcW.toDouble() / srcH
        val sw: Int
        val sh: Int
        if (srcAR > targetAR) {
            sh = srcH
            sw = Math.round(srcH * targetAR).toInt()
        } else {
            sw = srcW
            sh = Math.round(srcW / targetAR).toInt()
        }
        val sx = floor((srcW - sw) / 2.0).toInt()
        val sy = floor((srcH - sh) / 2.0).toInt()
        return intArrayOf(sx, sy, sw, sh)
    }

    /** Source rect for a frame given the interactive crop (normalized) or cropMode. */
    private fun srcRect(fw: Int, fh: Int, dstW: Int, dstH: Int, cropMode: String, crop: DoubleArray?): IntArray {
        if (crop != null && crop.size == 4 && crop[2] > 0 && crop[3] > 0) {
            var sx = Math.round(crop[0] * fw).toInt()
            var sy = Math.round(crop[1] * fh).toInt()
            var sw = Math.round(crop[2] * fw).toInt()
            var sh = Math.round(crop[3] * fh).toInt()
            if (sx < 0) sx = 0
            if (sy < 0) sy = 0
            if (sw < 1) sw = 1
            if (sh < 1) sh = 1
            if (sx + sw > fw) sw = fw - sx
            if (sy + sh > fh) sh = fh - sy
            return intArrayOf(sx, sy, sw, sh)
        }
        if (cropMode == "cover") return coverCrop(fw, fh, dstW, dstH)
        return intArrayOf(0, 0, fw, fh)
    }

    // Crop/scale a source bitmap into `dst` (reused) and read out RGBA bytes.
    private fun resizeFrame(
        src: Bitmap,
        dst: Bitmap,
        canvas: Canvas,
        dstW: Int,
        dstH: Int,
        cropMode: String,
        crop: DoubleArray?,
        bgColor: Int,
        pixels: IntArray,
        rgba: ByteArray,
    ): ByteArray {
        if (crop != null && crop.size == 4 && crop[2] > 0 && crop[3] > 0) {
            // Viewport crop — matches the Flutter image page's renderViewportRgba.
            // The normalized rect may extend beyond the frame (the user zoomed
            // out / panned past an edge): map it onto the full output and fill
            // anything outside the source with the opaque background so the
            // letterbox looks the same as the on-screen preview.
            val fw = src.width
            val fh = src.height
            val scaleX = (dstW / (crop[2] * fw)).toFloat()
            val scaleY = (dstH / (crop[3] * fh)).toFloat()
            val tx = (-crop[0] * dstW / crop[2]).toFloat()
            val ty = (-crop[1] * dstH / crop[3]).toFloat()
            canvas.drawColor(bgColor or 0xFF000000.toInt(), PorterDuff.Mode.SRC)
            canvas.save()
            canvas.translate(tx, ty)
            canvas.scale(scaleX, scaleY)
            canvas.drawBitmap(src, 0f, 0f, paint)
            canvas.restore()
        } else {
            // No interactive crop (e.g. first frame unreadable) → centered
            // cover-crop / stretch as before.
            val r = srcRect(src.width, src.height, dstW, dstH, cropMode, null)
            val srcR = Rect(r[0], r[1], r[0] + r[2], r[1] + r[3])
            val dstR = RectF(0f, 0f, dstW.toFloat(), dstH.toFloat())
            canvas.drawColor(0, PorterDuff.Mode.CLEAR)
            canvas.drawBitmap(src, srcR, dstR, paint)
        }

        dst.getPixels(pixels, 0, dstW, 0, 0, dstW, dstH)
        for (i in pixels.indices) {
            val c = pixels[i]
            val o = i * 4
            rgba[o] = ((c shr 16) and 0xFF).toByte()      // R
            rgba[o + 1] = ((c shr 8) and 0xFF).toByte()   // G
            rgba[o + 2] = (c and 0xFF).toByte()           // B
            rgba[o + 3] = ((c shr 24) and 0xFF).toByte()  // A
        }
        return rgba
    }

    fun convert(
        path: String,
        dstW: Int,
        dstH: Int,
        targetFps: Int,
        quality: Int,
        refine: Int,
        strips: Int,
        skipThresh: Int,
        keyint: Int,
        cropMode: String,
        crop: DoubleArray?,
        maxFrames: Int,
        bgColor: Int,
        cancel: AtomicBoolean,
        progress: Progress?,
    ): Result {
        require(dstW and 3 == 0 && dstH and 3 == 0) { "分辨率必须是 4 的倍数" }

        if (isGif(path)) {
            return convertGif(
                path, dstW, dstH, targetFps, quality, refine, strips, skipThresh, keyint,
                cropMode, crop, maxFrames, bgColor, cancel, progress,
            )
        }

        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            val durationMs =
                r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val durationSec = durationMs / 1000.0

            var nativeFps = 25.0
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val frameCount =
                    r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT)
                        ?.toIntOrNull() ?: 0
                if (frameCount > 0 && durationSec > 0) nativeFps = frameCount / durationSec
            }
            if (nativeFps <= 0) nativeFps = 25.0

            val outFps = minOf(targetFps.toDouble(), nativeFps)
            var estTotal = if (durationSec > 0) floor(durationSec * outFps).toInt() else 0
            if (estTotal > maxFrames) estTotal = maxFrames
            val plannedTotal = maxOf(1, estTotal)

            val dst = Bitmap.createBitmap(dstW, dstH, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(dst)
            val pixels = IntArray(dstW * dstH)
            val rgba = ByteArray(dstW * dstH * 4)
            val enc = CinepakEncoder.Encoder(
                dstW, dstH,
                CinepakEncoder.Options(
                    quality = quality, refine = refine, strips = strips,
                    skipThresh = skipThresh, keyint = keyint,
                ),
            )
            val frames = ArrayList<ByteArray>()

            var j = 0
            while (j < plannedTotal && frames.size < maxFrames) {
                if (cancel.get()) throw Cancelled()
                val tUs = Math.round(j / outFps * 1_000_000.0)
                val bmp = r.getFrameAtTime(tUs, MediaMetadataRetriever.OPTION_CLOSEST)
                if (bmp == null) {
                    if (frames.isNotEmpty()) break
                    j++
                    continue
                }
                resizeFrame(bmp, dst, canvas, dstW, dstH, cropMode, crop, bgColor, pixels, rgba)
                bmp.recycle()
                frames.add(enc.encode(rgba))
                progress?.onProgress(frames.size, maxOf(estTotal, frames.size))
                j++
            }

            dst.recycle()
            if (frames.isEmpty()) throw RuntimeException("未能解码出任何帧")

            val muxFps = maxOf(1, Math.round(outFps).toInt())
            val avi = CvidAviMuxer.buildAvi(frames, dstW, dstH, muxFps)
            return Result(avi, dstW, dstH, frames.size, outFps)
        } finally {
            releaseRetriever(r)
        }
    }

    // GIF → AVI via android.graphics.Movie. Each output frame is sampled at
    // t_j = j/outFps ms, composited onto an opaque [bgColor] (transparent GIF
    // pixels take the background), then run through the same crop/resize +
    // Cinepak + AVI pipeline as video. Movie is deprecated but is the only
    // built-in GIF frame extractor, so the deprecation is intentional.
    @Suppress("DEPRECATION")
    private fun convertGif(
        path: String,
        dstW: Int,
        dstH: Int,
        targetFps: Int,
        quality: Int,
        refine: Int,
        strips: Int,
        skipThresh: Int,
        keyint: Int,
        cropMode: String,
        crop: DoubleArray?,
        maxFrames: Int,
        bgColor: Int,
        cancel: AtomicBoolean,
        progress: Progress?,
    ): Result {
        val bytes = File(path).readBytes()
        val movie = android.graphics.Movie.decodeByteArray(bytes, 0, bytes.size)
            ?: throw RuntimeException("无法解析 GIF")
        val gw = movie.width()
        val gh = movie.height()
        if (gw <= 0 || gh <= 0) throw RuntimeException("GIF 尺寸无效")

        val durationMs = movie.duration()
        val durationSec = durationMs / 1000.0
        val frameCount = countGifFrames(bytes)
        var nativeFps = 10.0
        if (frameCount > 0 && durationSec > 0) nativeFps = frameCount / durationSec
        if (nativeFps <= 0) nativeFps = 10.0

        val outFps = minOf(targetFps.toDouble(), nativeFps)
        var estTotal = if (durationSec > 0) floor(durationSec * outFps).toInt() else 1
        if (estTotal > maxFrames) estTotal = maxFrames
        val plannedTotal = maxOf(1, estTotal)

        val opaqueBg = bgColor or 0xFF000000.toInt()
        val srcBmp = Bitmap.createBitmap(gw, gh, Bitmap.Config.ARGB_8888)
        val srcCanvas = Canvas(srcBmp)
        val dst = Bitmap.createBitmap(dstW, dstH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(dst)
        val pixels = IntArray(dstW * dstH)
        val rgba = ByteArray(dstW * dstH * 4)
        val enc = CinepakEncoder.Encoder(
            dstW, dstH,
            CinepakEncoder.Options(
                quality = quality, refine = refine, strips = strips,
                skipThresh = skipThresh, keyint = keyint,
            ),
        )
        val frames = ArrayList<ByteArray>()

        try {
            var j = 0
            while (j < plannedTotal && frames.size < maxFrames) {
                if (cancel.get()) throw Cancelled()
                var tMs = if (durationMs > 0) Math.round(j / outFps * 1000.0).toInt() else 0
                if (durationMs > 0 && tMs >= durationMs) tMs = durationMs - 1
                srcCanvas.drawColor(opaqueBg, PorterDuff.Mode.SRC)
                movie.setTime(tMs)
                movie.draw(srcCanvas, 0f, 0f)
                resizeFrame(srcBmp, dst, canvas, dstW, dstH, cropMode, crop, bgColor, pixels, rgba)
                frames.add(enc.encode(rgba))
                progress?.onProgress(frames.size, maxOf(estTotal, frames.size))
                j++
            }
        } finally {
            srcBmp.recycle()
            dst.recycle()
        }

        if (frames.isEmpty()) throw RuntimeException("GIF 未能编码任何帧")
        val muxFps = maxOf(1, Math.round(outFps).toInt())
        val avi = CvidAviMuxer.buildAvi(frames, dstW, dstH, muxFps)
        return Result(avi, dstW, dstH, frames.size, outFps)
    }

    // ── scrolling-text video (danmaku "scroll" mode) ─────────────────────────
    // The firmware has no scrolling-text primitive, so a danmaku that should
    // scroll is rendered here as a seamless looping AVI: the pre-rendered text
    // bitmap [strip] (RGBA, stripW×stripH) is tiled every period = stripW + gap
    // pixels and swept right→left across a size×size opaque canvas (marquee
    // style — text enters from the right, exits left). One loop
    // period is exactly frameCount frames, so the step from the last frame back
    // to frame 0 advances by exactly period/frameCount px — the device's native
    // AVI looping is therefore seamless even if frameCount is capped. The strip
    // is drawn at 1:1 (the chosen font size is already in device pixels) and
    // vertically centered, matching the on-screen scroll preview.
    fun encodeScrollAvi(
        strip: ByteArray,
        stripW: Int,
        stripH: Int,
        size: Int,
        bgColor: Int,
        speedPxPerSec: Int,
        fps: Int,
        gap: Int,
        quality: Int,
        maxFrames: Int,
        cancel: AtomicBoolean,
        progress: Progress?,
    ): Result {
        require(size and 3 == 0) { "分辨率必须是 4 的倍数" }
        require(stripW > 0 && stripH > 0) { "字幕尺寸无效" }
        require(strip.size >= stripW * stripH * 4) { "字幕像素数据不完整" }

        val stripBmp = Bitmap.createBitmap(stripW, stripH, Bitmap.Config.ARGB_8888)
        stripBmp.copyPixelsFromBuffer(java.nio.ByteBuffer.wrap(strip))

        val speed = maxOf(1, speedPxPerSec)
        val safeFps = maxOf(1, fps)
        val period = stripW + maxOf(0, gap)
        var frameCount = Math.round(period.toDouble() / speed * safeFps).toInt()
        if (frameCount < 1) frameCount = 1
        if (frameCount > maxFrames) frameCount = maxFrames

        val opaqueBg = bgColor or 0xFF000000.toInt()
        val yOff = ((size - stripH) / 2.0).toFloat()

        val dst = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(dst)
        val pixels = IntArray(size * size)
        val rgba = ByteArray(size * size * 4)
        val enc = CinepakEncoder.Encoder(
            size, size,
            CinepakEncoder.Options(quality = quality, refine = 3, strips = 2, skipThresh = 720, keyint = 0),
        )
        val frames = ArrayList<ByteArray>(frameCount)

        try {
            for (j in 0 until frameCount) {
                if (cancel.get()) throw Cancelled()
                // right→left: baseX runs period→0 as j advances, so every tiled
                // copy shifts left each frame (seamless because tiling is periodic).
                val baseX = period.toDouble() * (frameCount - j) / frameCount
                canvas.drawColor(opaqueBg, PorterDuff.Mode.SRC)
                var x = baseX - period // one copy off the left edge, tiled rightward
                while (x < size) {
                    canvas.drawBitmap(stripBmp, x.toFloat(), yOff, paint)
                    x += period
                }
                dst.getPixels(pixels, 0, size, 0, 0, size, size)
                for (i in pixels.indices) {
                    val c = pixels[i]
                    val o = i * 4
                    rgba[o] = ((c shr 16) and 0xFF).toByte()     // R
                    rgba[o + 1] = ((c shr 8) and 0xFF).toByte()  // G
                    rgba[o + 2] = (c and 0xFF).toByte()          // B
                    rgba[o + 3] = ((c shr 24) and 0xFF).toByte() // A
                }
                frames.add(enc.encode(rgba))
                progress?.onProgress(frames.size, frameCount)
            }
        } finally {
            stripBmp.recycle()
            dst.recycle()
        }

        if (frames.isEmpty()) throw RuntimeException("字幕滚动帧生成失败")
        val avi = CvidAviMuxer.buildAvi(frames, size, size, safeFps)
        return Result(avi, size, size, frames.size, safeFps.toDouble())
    }

    // ── multi-image carousel (多图轮播) ───────────────────────────────────────
    // Compose a set of pre-framed RGBA images into a slideshow AVI(CVID). Each
    // image is already rendered to size×size on the Flutter side (its viewport
    // crop + background baked in), so there is no crop/resize here — just VQ.
    //
    // Each image becomes a forced key frame (self-decodable — "关键帧"); it is
    // then held for holds[i] displayed frames so the muxed clip plays at [fps]
    // for the user's chosen total duration. The held repeats are inter frames:
    // once an inter frame reproduces itself byte-for-byte the encoder recon is a
    // fixed point, so that frame is an idempotent no-op on the decoder and the
    // rest of the hold can be duplicated without re-running the (costly) VQ —
    // bounding real encodes to a few per image regardless of duration.
    fun encodeFrames(
        frames: List<ByteArray>,
        holds: IntArray,
        size: Int,
        fps: Int,
        quality: Int,
        cancel: AtomicBoolean,
        progress: Progress?,
    ): Result {
        require(size and 3 == 0) { "分辨率必须是 4 的倍数" }
        require(frames.isNotEmpty()) { "没有图片" }
        require(holds.size == frames.size) { "帧参数不匹配" }
        val need = size * size * 4
        val safeFps = maxOf(1, fps)

        var total = 0
        for (h in holds) total += maxOf(1, h)

        val enc = CinepakEncoder.Encoder(
            size, size,
            CinepakEncoder.Options(quality = quality, refine = 3, strips = 2, skipThresh = 720, keyint = 0),
        )
        val out = ArrayList<ByteArray>(total)

        for (i in frames.indices) {
            if (cancel.get()) throw Cancelled()
            val rgba = frames[i]
            require(rgba.size >= need) { "图片像素数据不完整" }

            out.add(enc.encode(rgba, forceKey = true))
            progress?.onProgress(out.size, total)

            val hold = maxOf(1, holds[i])
            var h = 1
            var prevInter: ByteArray? = null
            while (h < hold) {
                if (cancel.get()) throw Cancelled()
                val inter = enc.encode(rgba, forceKey = false)
                out.add(inter)
                h++
                progress?.onProgress(out.size, total)
                if (prevInter != null && inter.contentEquals(prevInter)) {
                    // Fixed point reached — duplicate the settled frame for the
                    // remaining holds (idempotent on the decoder).
                    while (h < hold) {
                        out.add(inter)
                        h++
                        progress?.onProgress(out.size, total)
                    }
                    break
                }
                prevInter = inter
            }
        }

        if (out.isEmpty()) throw RuntimeException("未能编码任何帧")
        val avi = CvidAviMuxer.buildAvi(out, size, size, safeFps)
        return Result(avi, size, size, out.size, safeFps.toDouble())
    }

    private fun releaseRetriever(r: MediaMetadataRetriever) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) r.close() else r.release()
        } catch (_: Exception) {
        }
    }
}
