package com.remotelab.experimenthome

import android.os.Process
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Force-kill the process when the app is actually closing (swipe from
    // recents, or back-press out of the root screen). In a Flutter single-
    // Activity app, isFinishing is only true in these two cases — it is NOT
    // true during in-app Flutter navigation, so this is safe.
    override fun onDestroy() {
        super.onDestroy()
        if (isFinishing) {
            Process.killProcess(Process.myPid())
        }
    }
}
