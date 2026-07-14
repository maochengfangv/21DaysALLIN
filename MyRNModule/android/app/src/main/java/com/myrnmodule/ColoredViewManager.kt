package com.myrnmodule

import android.content.Context
import android.graphics.Color
import android.view.View
import com.facebook.react.uimanager.BaseViewManager
import com.facebook.react.uimanager.LayoutShadowNode
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp

/**
 * Fabric Native Component: NativeColoredView (Android)
 * 支持 color 和 cornerRadius 属性
 */
class ColoredViewManager : BaseViewManager<View, LayoutShadowNode>() {

    override fun getName(): String = "NativeColoredView"

    override fun createViewInstance(context: ThemedReactContext): View {
        return View(context)
    }

    override fun getShadowNodeClass(): Class<out LayoutShadowNode> = LayoutShadowNode::class.java

    @ReactProp(name = "color", customType = "Color")
    fun setColor(view: View, color: Int?) {
        if (color != null) {
            view.setBackgroundColor(color)
        }
    }

    @ReactProp(name = "cornerRadius", defaultFloat = 0f)
    fun setCornerRadius(view: View, radius: Float) {
        view.clipToOutline = true
        view.outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(view: View, outline: android.graphics.Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, radius)
            }
        }
    }
}
