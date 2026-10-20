package dev.shuttr.shuttr

import android.content.Context
import android.graphics.Bitmap
import android.opengl.GLES20
import androidx.annotation.OptIn
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram

/// One Media3 video effect that runs shaders/video_look.glsl over every
/// frame, with the look's parameters as uniforms. `params` is the Dart
/// VideoLook's JSON (lib/features/video/video_look.dart).
@OptIn(UnstableApi::class)
class VideoLookEffect(
    private val params: Map<String, Any?>,
    private val lut: Bitmap?,
    private val seed: Float,
) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram =
        VideoLookShaderProgram(context, params, lut, seed)
}

@OptIn(UnstableApi::class)
private class VideoLookShaderProgram(
    context: Context,
    private val params: Map<String, Any?>,
    lut: Bitmap?,
    private val seed: Float,
) : BaseGlShaderProgram(/* useHighPrecisionColorComponents= */ false, /* texturePoolCapacity= */ 1) {

    private val program: GlProgram
    private val lutTexture: Int
    private var width = 0
    private var height = 0

    init {
        try {
            program = GlProgram(context, "shaders/video_look_vertex.glsl", "shaders/video_look.glsl")
            program.setBufferAttribute(
                "aFramePosition",
                GlUtil.getNormalizedCoordinateBounds(),
                GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE,
            )
            lutTexture = if (lut != null) GlUtil.createTexture(lut) else 0
        } catch (e: Exception) {
            throw VideoFrameProcessingException(e)
        }
    }

    override fun configure(inputWidth: Int, inputHeight: Int): Size {
        width = inputWidth
        height = inputHeight
        return Size(inputWidth, inputHeight)
    }

    private fun f(key: String, fallback: Float = 0f): Float =
        (params[key] as? Number)?.toFloat() ?: fallback

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        try {
            program.use()
            program.setSamplerTexIdUniform("uTexSampler", inputTexId, /* texUnitIndex= */ 0)
            if (lutTexture != 0) {
                program.setSamplerTexIdUniform("uLut", lutTexture, /* texUnitIndex= */ 1)
            }
            program.setFloatUniform("uHasLut", if (lutTexture != 0) 1f else 0f)
            program.setFloatsUniform("uSize", floatArrayOf(width.toFloat(), height.toFloat()))
            program.setFloatUniform("uTime", presentationTimeUs / 1_000_000f)
            program.setFloatUniform("uSeed", seed)
            program.setFloatUniform("uExposure", f("exposure"))
            program.setFloatUniform("uContrast", f("contrast", 1f))
            program.setFloatUniform("uSaturation", f("saturation", 1f))
            program.setFloatUniform("uBlackLift", f("blackLift"))
            program.setFloatUniform("uVignette", f("vignette"))
            program.setFloatUniform("uLumaBlur", f("lumaBlur"))
            program.setFloatUniform("uChromaBlur", f("chromaBlur"))
            program.setFloatUniform("uChromaShift", f("chromaShift"))
            program.setFloatUniform("uSharpen", f("sharpen"))
            program.setFloatUniform("uNoise", f("noise"))
            program.setFloatUniform("uChromaNoise", f("chromaNoise"))
            program.setFloatUniform("uGrain", f("grain"))
            program.setFloatUniform("uLineJitter", f("lineJitter"))
            program.setFloatUniform("uTracking", f("tracking"))
            program.setFloatUniform("uHeadSwitch", f("headSwitch"))
            program.setFloatUniform("uInterlace", f("interlace"))
            program.setFloatUniform("uGateWeave", f("gateWeave"))
            program.setFloatUniform("uFlicker", f("flicker"))
            program.setFloatUniform("uDust", f("dust"))
            program.setFloatUniform("uGateMask", f("gateMask"))
            program.setFloatUniform("uWobble", f("wobble"))
            program.setFloatUniform("uNightVision", f("nightVision"))
            program.bindAttributesAndUniforms()
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, /* first= */ 0, /* count= */ 4)
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e, presentationTimeUs)
        }
    }

    override fun release() {
        super.release()
        try {
            program.delete()
            if (lutTexture != 0) GlUtil.deleteTexture(lutTexture)
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e)
        }
    }
}
