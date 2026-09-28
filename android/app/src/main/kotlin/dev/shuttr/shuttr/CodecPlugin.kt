package dev.shuttr.shuttr

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlin.math.max

/// Native JPEG decode (downsampled, EXIF-oriented) and encode for the
/// render pipeline. Pure-Dart JPEG encoding is too slow on budget phones —
/// see docs/ARCHITECTURE.md D-021 and docs/BUILD_PLAN.md S2.
///
/// Everything runs on Dispatchers.Default (off the main thread); results are
/// posted back via the main-thread MethodChannel.Result.
class CodecPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val scope = CoroutineScope(Dispatchers.Default)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "shuttr/codec")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "decodeForRender" -> {
                val path = call.argument<String>("path")
                val maxLongEdge = call.argument<Int>("maxLongEdge")
                if (path == null || maxLongEdge == null) {
                    result.error("bad_args", "path and maxLongEdge are required", null)
                    return
                }
                scope.launch {
                    try {
                        val decoded = decodeForRender(path, maxLongEdge)
                        result.postSuccess(decoded)
                    } catch (e: Exception) {
                        result.postError("decode_failed", e.message, null)
                    }
                }
            }
            "encodeJpeg" -> {
                val rgba = call.argument<ByteArray>("rgba")
                val width = call.argument<Int>("width")
                val height = call.argument<Int>("height")
                val quality = call.argument<Int>("quality")
                val outPath = call.argument<String>("outPath")
                if (rgba == null || width == null || height == null ||
                    quality == null || outPath == null
                ) {
                    result.error("bad_args", "rgba, width, height, quality, outPath are required", null)
                    return
                }
                scope.launch {
                    try {
                        encodeJpeg(rgba, width, height, quality, outPath)
                        result.postSuccess(null)
                    } catch (e: Exception) {
                        result.postError("encode_failed", e.message, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    /// Decodes [path] to RGBA8888, downsampled so its long edge is at most
    /// [maxLongEdge], oriented per EXIF. Uses inSampleSize so a large source
    /// file is never fully decoded before downscaling.
    private fun decodeForRender(path: String, maxLongEdge: Int): Map<String, Any> {
        val boundsOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, boundsOptions)
        val sourceLongEdge = max(boundsOptions.outWidth, boundsOptions.outHeight)

        var sampleSize = 1
        while (sourceLongEdge / (sampleSize * 2) >= maxLongEdge) {
            sampleSize *= 2
        }

        val decodeOptions = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        var bitmap = BitmapFactory.decodeFile(path, decodeOptions)
            ?: throw IllegalStateException("BitmapFactory.decodeFile returned null for $path")

        // Exact scale down to maxLongEdge (inSampleSize only gives powers of two).
        val currentLongEdge = max(bitmap.width, bitmap.height)
        if (currentLongEdge > maxLongEdge) {
            val scale = maxLongEdge.toFloat() / currentLongEdge
            val newWidth = (bitmap.width * scale).toInt().coerceAtLeast(1)
            val newHeight = (bitmap.height * scale).toInt().coerceAtLeast(1)
            val scaled = Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
            if (scaled !== bitmap) bitmap.recycle()
            bitmap = scaled
        }

        val orientation = ExifInterface(path).getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )
        val rotationDegrees = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        if (rotationDegrees != 0f) {
            val matrix = Matrix().apply { postRotate(rotationDegrees) }
            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotated !== bitmap) bitmap.recycle()
            bitmap = rotated
        }

        val buffer = ByteBuffer.allocate(bitmap.byteCount)
        bitmap.copyPixelsToBuffer(buffer)
        val rgba = buffer.array()
        val width = bitmap.width
        val height = bitmap.height
        bitmap.recycle()

        return mapOf("rgba" to rgba, "width" to width, "height" to height)
    }

    private fun encodeJpeg(
        rgba: ByteArray,
        width: Int,
        height: Int,
        quality: Int,
        outPath: String,
    ) {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(rgba))

        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(0, 100), output)
        bitmap.recycle()

        File(outPath).parentFile?.mkdirs()
        File(outPath).writeBytes(output.toByteArray())
    }

    /// Posts a success result on the main thread (MethodChannel.Result is
    /// not thread-safe and must be called from the platform thread).
    private fun Result.postSuccess(value: Any?) {
        android.os.Handler(android.os.Looper.getMainLooper()).post { success(value) }
    }

    private fun Result.postError(code: String, message: String?, details: Any?) {
        android.os.Handler(android.os.Looper.getMainLooper()).post { error(code, message, details) }
    }
}
