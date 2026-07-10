package com.myrnapp01.nativekit

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.TextView
import com.facebook.react.uimanager.PixelUtil

class InterviewFabricCardView(context: Context) : FrameLayout(context) {
  private val backgroundShape = GradientDrawable()

  private val labelView =
    TextView(context).apply {
      gravity = Gravity.CENTER
      setTextColor(Color.WHITE)
      textSize = 18f
      setTypeface(typeface, Typeface.BOLD)
      text = "Fabric Native Card"
      layoutParams =
        LayoutParams(
          LayoutParams.MATCH_PARENT,
          LayoutParams.MATCH_PARENT,
        )
    }

  init {
    backgroundShape.cornerRadius = PixelUtil.toPixelFromDIP(16f)
    backgroundShape.setColor(Color.parseColor("#1D4ED8"))
    background = backgroundShape
    setPadding(24, 24, 24, 24)
    addView(labelView)
    clipToOutline = true
  }

  fun setLabel(value: String?) {
    labelView.text = if (value.isNullOrBlank()) "Fabric Native Card" else value
  }

  fun setCardBackgroundColor(value: Int?) {
    backgroundShape.setColor(value ?: Color.parseColor("#1D4ED8"))
  }

  fun setCornerRadius(value: Float?) {
    backgroundShape.cornerRadius = PixelUtil.toPixelFromDIP(value ?: 16f)
  }
}
