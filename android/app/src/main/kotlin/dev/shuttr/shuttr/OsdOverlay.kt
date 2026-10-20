package dev.shuttr.shuttr

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import androidx.annotation.OptIn
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import java.util.Calendar
import java.util.Locale

/// The camcorder's on-screen display burnt into the picture: date and time
/// ticking along with the recording, REC and a tape counter, or VHS's PLAY.
/// Drawn as a full-frame transparent bitmap, redrawn only when the text
/// changes (about once a second), so it costs almost nothing per frame.
@OptIn(UnstableApi::class)
class OsdOverlay(
    private val osdStyle: String,
    private val startMillis: Long,
    private val yearOverride: Int?,
) : BitmapOverlay() {
    private var frameSize = Size(640, 480)
    private var lastKey: String? = null
    private var lastBitmap: Bitmap? = null

    override fun configure(videoSize: Size) {
        super.configure(videoSize)
        frameSize = videoSize
    }

    override fun getBitmap(presentationTimeUs: Long): Bitmap {
        val elapsedMs = presentationTimeUs / 1000
        val halfSeconds = elapsedMs / 500
        val key = "$osdStyle/$halfSeconds"
        val cached = lastBitmap
        if (key == lastKey && cached != null) return cached

        val bitmap = Bitmap.createBitmap(frameSize.width, frameSize.height, Bitmap.Config.ARGB_8888)
        draw(Canvas(bitmap), elapsedMs, blinkOn = halfSeconds % 2 == 0L)
        lastKey = key
        lastBitmap = bitmap
        return bitmap
    }

    private fun draw(canvas: Canvas, elapsedMs: Long, blinkOn: Boolean) {
        val w = frameSize.width.toFloat()
        val h = frameSize.height.toFloat()
        // Sized off the short side, so an upright clip gets the same OSD as
        // a landscape one rather than giant text.
        val short = minOf(w, h)
        val size = short * 0.055f
        val margin = short * 0.07f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            textSize = size
            color = if (osdStyle == "nightVision") Color.rgb(200, 255, 200) else Color.WHITE
            setShadowLayer(size * 0.08f, size * 0.06f, size * 0.06f, Color.BLACK)
        }
        val red = Paint(paint).apply { color = Color.rgb(235, 40, 40) }

        val cal = Calendar.getInstance().apply {
            timeInMillis = startMillis + elapsedMs
            if (yearOverride != null) set(Calendar.YEAR, yearOverride)
        }
        val month = MONTHS[cal.get(Calendar.MONTH)]
        val day = cal.get(Calendar.DAY_OF_MONTH)
        val year = cal.get(Calendar.YEAR)
        val hour24 = cal.get(Calendar.HOUR_OF_DAY)
        val hour12 = if (hour24 % 12 == 0) 12 else hour24 % 12
        val ampm = if (hour24 < 12) "AM" else "PM"
        val min = cal.get(Calendar.MINUTE)
        val sec = cal.get(Calendar.SECOND)
        val totalSec = elapsedMs / 1000
        val counter = String.format(Locale.US, "%d:%02d:%02d", totalSec / 3600, (totalSec / 60) % 60, totalSec % 60)

        fun left(text: String, y: Float, p: Paint = paint) = canvas.drawText(text, margin, y, p)
        fun right(text: String, y: Float, p: Paint = paint) =
            canvas.drawText(text, w - margin - p.measureText(text), y, p)

        val top = margin + size
        val bottom = h - margin
        when (osdStyle) {
            "vhs" -> {
                if (elapsedMs < 4000) left("PLAY ▶", top)
                left(String.format(Locale.US, "%s %2d:%02d", ampm, hour12, min), bottom - size * 1.3f)
                left(String.format(Locale.US, "%s. %d %d", month, day, year), bottom)
            }
            "camcorder" -> {
                if (blinkOn) left("●", top, red)
                left("   REC", top)
                right(counter, top)
                right(String.format(Locale.US, "%s %2d %d", month, day, year), bottom - size * 1.3f)
                right(String.format(Locale.US, "%2d:%02d:%02d %s", hour12, min, sec, ampm), bottom)
            }
            "minidv" -> {
                left("REC", top, red)
                if (blinkOn) left("    ●", top, red)
                val frames = (elapsedMs % 1000) * 30 / 1000
                right(String.format(Locale.US, "SP %s:%02d", counter, frames), top)
                right(String.format(Locale.US, "%02d:%02d:%02d", hour24, min, sec), bottom - size * 1.3f)
                right(String.format(Locale.US, "%d. %s. %d", day, month, year), bottom)
            }
            "nightVision" -> {
                left("NIGHT", top)
                if (blinkOn) right("● REC", top, red)
                right(counter, bottom)
            }
        }
    }

    companion object {
        private val MONTHS = arrayOf("JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC")
    }
}
