package dev.shuttr.shuttr

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.FrameDropEffect
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/// Develops a recorded (or imported) clip into a camcorder look, after
/// recording, never live (CLAUDE.md rule 2). Uses Media3 Transformer, the
/// retired-ffmpeg replacement (CLAUDE.md rule 10):
///
///   input mp4 → [drop to the look's frame rate] → [scale + crop to the
///   look's 4:3/16:9 size] → [video_look.glsl per frame] → [OSD overlay]
///   → H.264 at the look's (often deliberately low) bitrate
///
/// and the soundtrack through TapeAudioProcessor → AAC. One job at a time.
@OptIn(UnstableApi::class)
class VideoPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var assets: FlutterPlugin.FlutterAssets
    private val main = Handler(Looper.getMainLooper())
    private val io = CoroutineScope(Dispatchers.IO)

    private var transformer: Transformer? = null
    private val progress = ProgressHolder()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        assets = binding.flutterAssets
        channel = MethodChannel(binding.binaryMessenger, "shuttr/video")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        transformer?.cancel()
        transformer = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "process" -> process(call, result)
            "progress" -> {
                val t = transformer
                if (t == null) {
                    result.success(-1)
                } else {
                    val state = t.getProgress(progress)
                    result.success(if (state == Transformer.PROGRESS_STATE_AVAILABLE) progress.progress else -1)
                }
            }
            "cancel" -> {
                transformer?.cancel()
                transformer = null
                result.success(null)
            }
            "thumbnail" -> thumbnail(call, result)
            else -> result.notImplemented()
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun process(call: MethodCall, result: MethodChannel.Result) {
        if (transformer != null) {
            result.error("busy", "A video is already developing", null)
            return
        }
        val input = call.argument<String>("input")
        val output = call.argument<String>("output")
        val look = call.argument<Map<String, Any?>>("look")
        if (input == null || output == null || look == null) {
            result.error("bad_args", "input, output and look are required", null)
            return
        }
        val startMillis = (call.argument<Number>("startMillis") ?: System.currentTimeMillis()).toLong()
        val yearOverride = call.argument<Int>("yearOverride")
        val seed = (call.argument<Number>("seed") ?: 1.0).toFloat()

        // Decode the LUT off the main thread, then build and start on main
        // (Transformer must be driven from a Looper thread).
        io.launch {
            val lut = (look["lutAsset"] as? String)?.let { loadAssetBitmap(it) }
            val portrait = isPortrait(input)
            main.post { start(input, output, look, lut, portrait, startMillis, yearOverride, seed, result) }
        }
    }

    private fun start(
        input: String,
        output: String,
        look: Map<String, Any?>,
        lut: Bitmap?,
        portrait: Boolean,
        startMillis: Long,
        yearOverride: Int?,
        seed: Float,
        result: MethodChannel.Result,
    ) {
        // Looks are specified landscape (4:3, 16:9), like the real formats.
        // An upright phone clip keeps its orientation: the same format,
        // turned on its side, rather than a thin slice cut from the middle.
        val lw = (look["outputWidth"] as Number).toInt()
        val lh = (look["outputHeight"] as Number).toInt()
        val width = if (portrait) lh else lw
        val height = if (portrait) lw else lh
        val fps = (look["fps"] as? Number)?.toFloat()
        val osd = look["osd"] as? String ?: "none"

        val videoEffects = mutableListOf<Effect>()
        if (fps != null) videoEffects.add(FrameDropEffect.createDefaultFrameDropEffect(fps))
        videoEffects.add(Presentation.createForWidthAndHeight(width, height, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP))
        videoEffects.add(VideoLookEffect(look, lut, seed))
        if (osd != "none") {
            videoEffects.add(OverlayEffect(listOf(OsdOverlay(osd, startMillis, yearOverride))))
        }

        val edited = EditedMediaItem.Builder(MediaItem.fromUri(android.net.Uri.fromFile(File(input))))
            .setEffects(Effects(listOf(TapeAudioProcessor(look)), videoEffects))
            .build()

        val bitrate = ((look["bitrateKbps"] as? Number)?.toInt() ?: 4000) * 1000
        val encoders = DefaultEncoderFactory.Builder(context)
            .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(bitrate).build())
            .build()

        File(output).parentFile?.mkdirs()
        val t = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoders)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    transformer = null
                    result.success(mapOf("path" to output, "durationMs" to exportResult.durationMs))
                }

                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                    transformer = null
                    result.error("export_failed", exportException.message, exportException.errorCodeName)
                }
            })
            .build()
        transformer = t
        try {
            t.start(edited, output)
        } catch (e: Exception) {
            transformer = null
            result.error("export_failed", e.message, null)
        }
    }

    /// Whether the clip displays taller than wide, after its rotation tag.
    private fun isPortrait(path: String): Boolean {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toInt() ?: 0
            val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toInt() ?: 0
            val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
            if (rot == 90 || rot == 270) w > h else h > w
        } catch (e: Exception) {
            false
        } finally {
            r.release()
        }
    }

    private fun loadAssetBitmap(assetPath: String): Bitmap? = try {
        context.assets.open(assets.getAssetFilePathByName(assetPath)).use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inScaled = false })
        }
    } catch (e: Exception) {
        null
    }

    /// A poster frame for the gallery grid, plus the clip's duration.
    private fun thumbnail(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val out = call.argument<String>("out")
        if (path == null || out == null) {
            result.error("bad_args", "path and out are required", null)
            return
        }
        io.launch {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(path)
                val durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0
                val frame = retriever.getFrameAtTime(minOf(500_000L, durationMs * 500), MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                if (frame != null) {
                    FileOutputStream(out).use { frame.compress(Bitmap.CompressFormat.JPEG, 85, it) }
                    frame.recycle()
                }
                main.post { result.success(durationMs) }
            } catch (e: Exception) {
                main.post { result.error("thumbnail_failed", e.message, null) }
            } finally {
                retriever.release()
            }
        }
    }
}
