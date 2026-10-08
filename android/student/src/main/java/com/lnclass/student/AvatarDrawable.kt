package com.lnclass.student

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Shader
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import androidx.core.content.ContextCompat
import kotlin.math.max

// Avatar rond de 32 dp (UDR-0080 §3.3) : la photo recadrée si elle est chargée, sinon les initiales sur le bleu de
// marque. Il ignore la teinte que la barre applique à son icône de navigation.
class AvatarDrawable(context: Context, private val initials: String) : Drawable() {
    private val size = (32 * context.resources.displayMetrics.density).toInt()

    private val background = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = ContextCompat.getColor(context, R.color.avatar_background)
    }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = ContextCompat.getColor(context, R.color.avatar_text)
        textAlign = Paint.Align.CENTER
        textSize = size * 0.4f
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }
    private var photo: Paint? = null

    fun setPhoto(bitmap: Bitmap) {
        val scale = size.toFloat() / max(1, minOf(bitmap.width, bitmap.height))
        val matrix = Matrix().apply {
            setScale(scale, scale)
            postTranslate((size - bitmap.width * scale) / 2f, (size - bitmap.height * scale) / 2f)
        }
        photo = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = BitmapShader(bitmap, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply { setLocalMatrix(matrix) }
        }
        invalidateSelf()
    }

    override fun draw(canvas: Canvas) {
        val radius = size / 2f
        canvas.save()
        canvas.translate(bounds.left.toFloat(), bounds.top.toFloat())
        val photoPaint = photo
        if (photoPaint != null) {
            canvas.drawCircle(radius, radius, radius, photoPaint)
        } else {
            canvas.drawCircle(radius, radius, radius, background)
            val baseline = radius - (text.descent() + text.ascent()) / 2f
            canvas.drawText(initials, radius, baseline, text)
        }
        canvas.restore()
    }

    override fun getIntrinsicWidth() = size

    override fun getIntrinsicHeight() = size

    override fun setAlpha(alpha: Int) = Unit

    override fun setColorFilter(colorFilter: ColorFilter?) = Unit

    @Deprecated("Deprecated in Java")
    override fun getOpacity() = PixelFormat.TRANSLUCENT
}
