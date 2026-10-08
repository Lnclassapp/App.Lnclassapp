package com.lnclass.teacher

import android.app.Application
import com.lnclass.shell.Shell

// Configuration Hotwire Native de l'app enseignants, une fois au lancement (ADR-0085 §4.1 et §4.3) : le socle fait le reste.
class TeacherApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        Shell.configure(
            context = this,
            userAgentPrefix = "LnclassTeacherAndroid/${BuildConfig.VERSION_NAME};",
            baseUrl = BuildConfig.BASE_URL,
            debug = BuildConfig.DEBUG,
            accountMenuPath = "/teachers/menu"
        )
    }
}
