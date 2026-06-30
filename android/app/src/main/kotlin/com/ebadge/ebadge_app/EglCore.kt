package com.ebadge.ebadge_app

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.view.Surface

/**
 * Minimal EGL 1.4 / GLES2 context holder.
 *
 * Owns a single shared [EGLContext] and can spawn multiple window surfaces from
 * Android [Surface]s (preview texture + encoder input surface), so one set of GL
 * resources renders to both targets.
 */
class EglCore {
    private val display: EGLDisplay
    private val context: EGLContext
    private val config: EGLConfig

    /** Recordable-Android attribute, so encoder input surfaces are valid. */
    private val eglRecordableAndroid = 0x3142

    init {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (display === EGL14.EGL_NO_DISPLAY) {
            throw RuntimeException("无法获取 EGL display")
        }
        val version = IntArray(2)
        if (!EGL14.eglInitialize(display, version, 0, version, 1)) {
            throw RuntimeException("eglInitialize 失败")
        }

        val attribList = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            eglRecordableAndroid, 1,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        if (!EGL14.eglChooseConfig(
                display, attribList, 0, configs, 0, configs.size, numConfigs, 0,
            )
        ) {
            throw RuntimeException("eglChooseConfig 失败")
        }
        config = configs[0] ?: throw RuntimeException("无可用 EGLConfig")

        val ctxAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
        context = EGL14.eglCreateContext(
            display, config, EGL14.EGL_NO_CONTEXT, ctxAttribs, 0,
        )
        if (context === EGL14.EGL_NO_CONTEXT) {
            throw RuntimeException("eglCreateContext 失败")
        }
    }

    /** A tiny pbuffer used as a "home" surface to bootstrap the GL context. */
    fun createOffscreenSurface(width: Int, height: Int): EGLSurface {
        val attribs = intArrayOf(
            EGL14.EGL_WIDTH, width,
            EGL14.EGL_HEIGHT, height,
            EGL14.EGL_NONE,
        )
        val eglSurface = EGL14.eglCreatePbufferSurface(display, config, attribs, 0)
        if (eglSurface === EGL14.EGL_NO_SURFACE) {
            throw RuntimeException("eglCreatePbufferSurface 失败")
        }
        return eglSurface
    }

    fun createWindowSurface(surface: Surface): EGLSurface {
        val attribs = intArrayOf(EGL14.EGL_NONE)
        val eglSurface = EGL14.eglCreateWindowSurface(display, config, surface, attribs, 0)
        if (eglSurface === EGL14.EGL_NO_SURFACE) {
            throw RuntimeException("eglCreateWindowSurface 失败")
        }
        return eglSurface
    }

    fun makeCurrent(eglSurface: EGLSurface) {
        if (!EGL14.eglMakeCurrent(display, eglSurface, eglSurface, context)) {
            throw RuntimeException("eglMakeCurrent 失败")
        }
    }

    fun makeNothingCurrent() {
        EGL14.eglMakeCurrent(
            display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT,
        )
    }

    fun swapBuffers(eglSurface: EGLSurface): Boolean =
        EGL14.eglSwapBuffers(display, eglSurface)

    /** Set the presentation timestamp (nanoseconds) for the encoder surface. */
    fun setPresentationTime(eglSurface: EGLSurface, nsecs: Long) {
        EGLExt.eglPresentationTimeANDROID(display, eglSurface, nsecs)
    }

    fun releaseSurface(eglSurface: EGLSurface) {
        EGL14.eglDestroySurface(display, eglSurface)
    }

    fun release() {
        if (display !== EGL14.EGL_NO_DISPLAY) {
            makeNothingCurrent()
            EGL14.eglDestroyContext(display, context)
            EGL14.eglReleaseThread()
            EGL14.eglTerminate(display)
        }
    }
}
