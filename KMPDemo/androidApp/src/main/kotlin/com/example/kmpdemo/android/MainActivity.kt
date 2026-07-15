package com.example.kmpdemo.android

import android.app.Activity
import android.os.Bundle
import android.widget.TextView
import com.example.kmpdemo.Greeting

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(
            TextView(this).apply {
                text = Greeting().greet()
                textSize = 24f
                setPadding(64, 64, 64, 64)
            }
        )
    }
}
