package dev.shuttr.shuttr

import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.BaseAudioProcessor
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.round
import kotlin.math.sin
import kotlin.math.tanh
import kotlin.random.Random

/// Makes the soundtrack sound like the format: a band-limited cheap mic
/// (high-pass + low-pass), tape saturation, hiss, wow & flutter (a slowly
/// wobbling delay line, which is literally what uneven tape speed does to
/// pitch), bit-crush for early digital, and projector clatter for Super 8.
/// 16-bit PCM in, 16-bit PCM out, same channel count.
@OptIn(UnstableApi::class)
class TapeAudioProcessor(params: Map<String, Any?>) : BaseAudioProcessor() {
    private fun f(params: Map<String, Any?>, key: String, fallback: Float) =
        (params[key] as? Number)?.toFloat() ?: fallback

    private val hiss = f(params, "hiss", 0f)
    private val lowpassHz = f(params, "lowpassHz", 20000f)
    private val highpassHz = f(params, "highpassHz", 20f)
    private val drive = f(params, "drive", 0f)
    private val crush = f(params, "crush", 0f)
    private val wow = f(params, "wow", 0f)
    private val projector = f(params, "projector", 0f)
    private val mono = params["mono"] as? Boolean ?: false

    private val random = Random(7)
    private var frameIndex = 0L

    // Per-channel filter and delay-line state, sized in onConfigure.
    private var hpPrevIn = FloatArray(0)
    private var hpPrevOut = FloatArray(0)
    private var lp1 = FloatArray(0)
    private var lp2 = FloatArray(0)
    private var hissState = 0f
    private var ring = Array(0) { FloatArray(0) }
    private var ringPos = 0

    override fun onConfigure(inputAudioFormat: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        if (inputAudioFormat.encoding != C.ENCODING_PCM_16BIT) {
            throw AudioProcessor.UnhandledAudioFormatException(inputAudioFormat)
        }
        val ch = inputAudioFormat.channelCount
        hpPrevIn = FloatArray(ch)
        hpPrevOut = FloatArray(ch)
        lp1 = FloatArray(ch)
        lp2 = FloatArray(ch)
        // ~100 ms of history for the wow delay line.
        ring = Array(ch) { FloatArray(max(1024, inputAudioFormat.sampleRate / 10)) }
        ringPos = 0
        frameIndex = 0
        return inputAudioFormat
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        val input = inputBuffer.order(ByteOrder.nativeOrder())
        val bytes = input.remaining()
        if (bytes == 0) return
        val out = replaceOutputBuffer(bytes)
        val format = inputAudioFormat
        val ch = format.channelCount
        val rate = format.sampleRate.toFloat()
        val frames = bytes / (2 * ch)

        val hpA = (1.0 / (1.0 + 2 * PI * highpassHz / rate)).toFloat()
        val lpA = exp(-2.0 * PI * lowpassHz / rate).toFloat()
        val driveGain = 1f + drive * 4f
        val driveNorm = tanh(driveGain.toDouble()).toFloat()
        val levels = if (crush > 0f) (1 shl (16 - (crush * 11).toInt()).coerceIn(4, 16)).toFloat() / 2f else 0f

        val samples = FloatArray(ch)
        for (i in 0 until frames) {
            for (c in 0 until ch) samples[c] = input.short / 32768f
            if (mono && ch > 1) {
                val m = samples.average().toFloat()
                for (c in 0 until ch) samples[c] = m
            }
            val t = frameIndex / rate

            // Wow (slow) and flutter (fast) as a modulated delay.
            val delaySamples = if (wow > 0f) {
                val ms = 8f + wow * (2.2f * sin(2 * PI * 0.5 * t).toFloat() +
                    0.35f * sin(2 * PI * 6.5 * t).toFloat())
                ms / 1000f * rate
            } else 0f

            // Projector: an 18 Hz mechanical clatter.
            val phase = (t * 18f) % 1f
            val clatter = if (projector > 0f) {
                (random.nextFloat() - 0.5f) * exp(-phase * 25f) * projector * 0.25f
            } else 0f

            // Hiss: slightly darkened white noise, shared across channels.
            hissState = 0.6f * hissState + 0.4f * (random.nextFloat() - 0.5f)
            val hissSample = hissState * hiss * 0.5f

            for (c in 0 until ch) {
                var x = samples[c]
                val ringBuf = ring[c]
                val size = ringBuf.size
                ringBuf[ringPos] = x
                if (delaySamples > 0f) {
                    val read = ringPos - delaySamples
                    val r0 = ((kotlin.math.floor(read).toInt() % size) + size) % size
                    val r1 = (r0 + 1) % size
                    val frac = read - kotlin.math.floor(read)
                    x = ringBuf[r0] * (1f - frac) + ringBuf[r1] * frac
                }

                // High-pass (small mic, no bass) then two-pole low-pass.
                val hp = hpA * (hpPrevOut[c] + x - hpPrevIn[c])
                hpPrevIn[c] = x
                hpPrevOut[c] = hp
                lp1[c] = (1f - lpA) * hp + lpA * lp1[c]
                lp2[c] = (1f - lpA) * lp1[c] + lpA * lp2[c]
                var y = lp2[c]

                if (drive > 0f) y = tanh((y * driveGain).toDouble()).toFloat() / driveNorm
                y += hissSample + clatter
                if (levels > 0f) y = round(y * levels) / levels

                out.putShort((y.coerceIn(-1f, 1f) * 32767f).toInt().toShort())
            }
            ringPos = (ringPos + 1) % ring[0].size
            frameIndex++
        }
        out.flip()
    }

    override fun onReset() {
        frameIndex = 0
        ringPos = 0
        hissState = 0f
    }
}
