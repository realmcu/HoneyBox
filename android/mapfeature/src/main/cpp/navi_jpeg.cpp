#include <android/bitmap.h>
#include <jni.h>
#include <turbojpeg.h>

#include <algorithm>
#include <cstdint>
#include <vector>

static jbyteArray encodeRgbaToJpeg(
        JNIEnv *env,
        unsigned char *pixels,
        int width,
        int height,
        int stride,
        int quality) {
    if (pixels == nullptr || width <= 0 || height <= 0 || stride < width * 4) {
        return nullptr;
    }

    const int clampedQuality = std::max(1, std::min(100, quality));
    tjhandle handle = tjInitCompress();
    if (handle == nullptr) {
        return nullptr;
    }

    unsigned char *jpegBuffer = nullptr;
    unsigned long jpegSize = 0;
    const int flags = TJFLAG_FASTDCT;

    const int rc = tjCompress2(
            handle,
            pixels,
            width,
            stride,
            height,
            TJPF_RGBA,
            &jpegBuffer,
            &jpegSize,
            TJSAMP_420,
            clampedQuality,
            flags);

    tjDestroy(handle);

    if (rc != 0 || jpegBuffer == nullptr || jpegSize == 0) {
        if (jpegBuffer != nullptr) {
            tjFree(jpegBuffer);
        }
        return nullptr;
    }

    jbyteArray result = env->NewByteArray(static_cast<jsize>(jpegSize));
    if (result != nullptr) {
        env->SetByteArrayRegion(
                result,
                0,
                static_cast<jsize>(jpegSize),
                reinterpret_cast<jbyte *>(jpegBuffer));
    }
    tjFree(jpegBuffer);
    return result;
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_map1_navi_TurboJpegEncoder_nativeEncode(
        JNIEnv *env,
        jobject,
        jobject bitmap,
        jint quality) {
    AndroidBitmapInfo info{};
    if (AndroidBitmap_getInfo(env, bitmap, &info) != ANDROID_BITMAP_RESULT_SUCCESS) {
        return nullptr;
    }
    if (info.format != ANDROID_BITMAP_FORMAT_RGBA_8888) {
        return nullptr;
    }

    void *pixels = nullptr;
    if (AndroidBitmap_lockPixels(env, bitmap, &pixels) != ANDROID_BITMAP_RESULT_SUCCESS) {
        return nullptr;
    }

    const int width = static_cast<int>(info.width);
    const int height = static_cast<int>(info.height);
    const int stride = static_cast<int>(info.stride);
    // Android ARGB_8888 memory is byte-ordered RGBA on little-endian devices.
    jbyteArray result = encodeRgbaToJpeg(
            env,
            static_cast<unsigned char *>(pixels),
            width,
            height,
            stride,
            static_cast<int>(quality));
    AndroidBitmap_unlockPixels(env, bitmap);
    return result;
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_map1_navi_TurboJpegEncoder_nativeEncodeRgba(
        JNIEnv *env,
        jobject,
        jobject buffer,
        jint width,
        jint height,
        jint rowStride,
        jint quality) {
    auto *pixels = static_cast<unsigned char *>(env->GetDirectBufferAddress(buffer));
    return encodeRgbaToJpeg(
            env,
            pixels,
            static_cast<int>(width),
            static_cast<int>(height),
            static_cast<int>(rowStride),
            static_cast<int>(quality));
}
