package com.myrnapp01.nativekit

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.viewmanagers.InterviewFabricCardManagerDelegate
import com.facebook.react.viewmanagers.InterviewFabricCardManagerInterface

@ReactModule(name = InterviewFabricCardManager.REACT_CLASS)
class InterviewFabricCardManager :
  SimpleViewManager<InterviewFabricCardView>(),
  InterviewFabricCardManagerInterface<InterviewFabricCardView> {

  private val delegate: ViewManagerDelegate<InterviewFabricCardView> =
    InterviewFabricCardManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<InterviewFabricCardView> = delegate

  override fun getName(): String = REACT_CLASS

  override fun createViewInstance(
    reactContext: ThemedReactContext,
  ): InterviewFabricCardView = InterviewFabricCardView(reactContext)

  override fun setLabel(view: InterviewFabricCardView, value: String?) {
    view.setLabel(value)
  }

  override fun setCardBackgroundColor(view: InterviewFabricCardView, value: Int?) {
    view.setCardBackgroundColor(value)
  }

  override fun setCornerRadius(view: InterviewFabricCardView, value: Float) {
    view.setCornerRadius(value)
  }

  companion object {
    const val REACT_CLASS = "InterviewFabricCard"
  }
}
