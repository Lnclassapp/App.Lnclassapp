package com.lnclass.student

import android.app.Application
import com.lnclass.shell.Shell

// Configuration Hotwire Native de l'app élèves, une fois au lancement (ADR-0084 §4.1 et §4.3) : le socle fait le reste.
class StudentApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        Shell.configure(
            context = this,
            userAgentPrefix = "LnclassStudentAndroid/${BuildConfig.VERSION_NAME};",
            baseUrl = BuildConfig.BASE_URL,
            debug = BuildConfig.DEBUG,
            accountMenuPath = "/students/menu"
        )
    }
}
