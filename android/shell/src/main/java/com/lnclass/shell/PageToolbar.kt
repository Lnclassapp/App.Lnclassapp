package com.lnclass.shell

import android.content.Context
import android.util.AttributeSet
import com.google.android.material.appbar.MaterialToolbar

// Barre du haut native : le titre est celui de la page, sans « · Élève · Lnclass » ni « · Enseignant · Lnclass »
// (UDR-0080 §3.3, UDR-0081 §3.3, UDR-0054).
class PageToolbar @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = com.google.android.material.R.attr.toolbarStyle
) : MaterialToolbar(context, attrs, defStyleAttr) {
    override fun setTitle(title: CharSequence?) {
        super.setTitle(title?.toString()?.substringBefore(TITLE_SEPARATOR))
    }

    private companion object {
        const val TITLE_SEPARATOR = " · "
    }
}
