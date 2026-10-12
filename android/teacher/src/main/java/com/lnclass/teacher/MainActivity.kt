package com.lnclass.teacher

import com.lnclass.shell.ShellActivity

// Activité unique : quatre onglets natifs, chacun avec sa pile de pages du site (ADR-0086 §4.3, UDR-0082 §3.3). Les
// liens /teacher-signup et /i/<code> (manifeste) s'ouvrent dans l'app.
class MainActivity : ShellActivity(R.layout.activity_main) {
    override val baseUrl = BuildConfig.BASE_URL

    override val tabs by lazy {
        listOf(
            tab("home", R.string.tab_home, R.drawable.ic_tab_home, "/?source=android", R.id.home_navigator_host),
            tab("classrooms", R.string.tab_classrooms, R.drawable.ic_tab_classrooms, "/teachers/classrooms", R.id.classrooms_navigator_host),
            tab("courses", R.string.tab_courses, R.drawable.ic_tab_courses, "/courses", R.id.courses_navigator_host),
            tab("announcements", R.string.tab_announcements, R.drawable.ic_tab_announcements, "/announcements", R.id.announcements_navigator_host)
        )
    }
}
