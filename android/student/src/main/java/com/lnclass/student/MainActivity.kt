package com.lnclass.student

import com.lnclass.shell.ShellActivity

// Activité unique : trois onglets natifs, chacun avec sa pile de pages du site (ADR-0084 §4.4). Les liens /c/<code>
// et /join (manifeste) s'ouvrent dans l'app.
class MainActivity : ShellActivity(R.layout.activity_main) {
    override val baseUrl = BuildConfig.BASE_URL

    override val tabs by lazy {
        listOf(
            tab("home", R.string.tab_home, R.drawable.ic_tab_home, "/?source=android", R.id.home_navigator_host),
            tab("courses", R.string.tab_courses, R.drawable.ic_tab_courses, "/courses", R.id.courses_navigator_host),
            tab("classroom", R.string.tab_classroom, R.drawable.ic_tab_classroom, "/students/classroom", R.id.classroom_navigator_host)
        )
    }
}
