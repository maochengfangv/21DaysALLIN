package com.myrnmodule

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.View
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.viewmanagers.NativeColoredViewManagerDelegate
import com.facebook.react.viewmanagers.NativeColoredViewManagerInterface

class ColoredView(context: ThemedReactContext) : View(context) {
    private val backgroundDrawable = GradientDrawable()
    private var fillColor: Int = Color.TRANSPARENT
    private var radius: Float = 0f

    init {
        background = backgroundDrawable
        refreshBackground()
    }

    fun updateColor(colorString: String?) {
        fillColor = try {
            if (colorString.isNullOrBlank()) Color.TRANSPARENT else Color.parseColor(colorString)
        } catch (_: IllegalArgumentException) {
            Color.TRANSPARENT
        }
        refreshBackground()
    }

    fun updateCornerRadius(nextRadius: Double) {
        radius = nextRadius.toFloat()
        refreshBackground()
    }

    private fun refreshBackground() {
        backgroundDrawable.cornerRadius = radius
        backgroundDrawable.setColor(fillColor)
    }
}

/**
 * Fabric Native Component: NativeColoredView (Android)
 * 支持 color 和 cornerRadius 属性
 */
class ColoredViewManager :
    SimpleViewManager<ColoredView>(),
    NativeColoredViewManagerInterface<ColoredView> {

    private val delegate: ViewManagerDelegate<ColoredView> =
        NativeColoredViewManagerDelegate(this)

    override fun getName(): String = "NativeColoredView"

    override fun getDelegate(): ViewManagerDelegate<ColoredView> = delegate

    override fun createViewInstance(context: ThemedReactContext): ColoredView {
        return ColoredView(context)
    }

    override fun setColor(view: ColoredView, value: String?) {
        view.updateColor(value)
    }

    override fun setCornerRadius(view: ColoredView, value: Double) {
        view.updateCornerRadius(value)
    }
}
