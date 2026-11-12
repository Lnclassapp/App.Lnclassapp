package com.lnclass.shell

import android.content.Context
import android.util.AttributeSet
import com.google.android.material.appbar.MaterialToolbar

// Barre du haut native : le titre est celui de la page, sans « · Élève · Lnclass » ni « · Enseignant · Lnclass »
// (UDR-0080 §3.3, UDR-0082 §3.3, UDR-0054).
class PageToolbar @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = androidx.appcompat.R.attr.toolbarStyle // attribut d'AppCompat, plus réexporté par le R de Material 1.14
) : MaterialToolbar(context, attrs, defStyleAttr) {
    override fun setTitle(title: CharSequence?) {
        super.setTitle(title?.toString()?.substringBefore(TITLE_SEPARATOR))
    }

    private companion object {
        const val TITLE_SEPARATOR = " · "
    }
}
