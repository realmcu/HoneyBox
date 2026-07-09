package com.ebadge.ebadge_app

import android.media.MediaPlayer
import android.view.Surface
import io.flutter.view.TextureRegistry

/**
 * A single looping video preview rendered into a Flutter external texture.
 *
 * Lets the video page play the *original* video (via the system [MediaPlayer])
 * inside the same circular pinch-zoom framing viewport used for cropping — no
 * frame extraction, no third-party plugin. One instance owns one
 * [TextureRegistry.SurfaceTextureEntry] + one [MediaPlayer]; [textureId] is
 * handed to Dart's `Texture` widget. Audio is muted (this is a motion preview).
 *
 * All calls happen on the main thread; [MediaPlayer] callbacks fire there too
 * (it's created on the main thread), so results can be delivered directly.
 */
class VideoPreviewPlayer(
    private val entry: TextureRegistry.SurfaceTextureEntry,
) {
    private val surface: Surface = Surface(entry.surfaceTexture())
    private var player: MediaPlayer? = null
    private var released = false

    val textureId: Long get() = entry.id()

    /**
     * Prepare [path] asynchronously. [onReady] receives (width, height,
     * durationMs) once the first frame is renderable; [onError] receives a
     * message on failure. Exactly one of them fires (unless [release]d first).
     */
    fun open(
        path: String,
        onReady: (Int, Int, Int) -> Unit,
        onError: (String) -> Unit,
    ) {
        val mp = MediaPlayer()
        player = mp
        mp.setSurface(surface)
        mp.isLooping = true
        mp.setVolume(0f, 0f) // silent motion preview
        mp.setOnPreparedListener { p ->
            if (released) return@setOnPreparedListener
            val w = p.videoWidth
            val h = p.videoHeight
            if (w > 0 && h > 0) entry.surfaceTexture().setDefaultBufferSize(w, h)
            onReady(w, h, p.duration)
        }
        mp.setOnErrorListener { _, what, extra ->
            if (!released) onError("play error $what/$extra")
            true
        }
        try {
            mp.setDataSource(path)
            mp.prepareAsync()
        } catch (e: Exception) {
            if (!released) onError(e.message ?: "open failed")
        }
    }

    fun play() {
        runCatching { player?.start() }
    }

    fun pause() {
        runCatching { if (player?.isPlaying == true) player?.pause() }
    }

    fun seekTo(ms: Int) {
        runCatching { player?.seekTo(ms) }
    }

    /** Release the player, surface and texture. Idempotent. */
    fun release() {
        if (released) return
        released = true
        runCatching { player?.stop() }
        runCatching { player?.release() }
        player = null
        surface.release()
        entry.release()
    }
}
