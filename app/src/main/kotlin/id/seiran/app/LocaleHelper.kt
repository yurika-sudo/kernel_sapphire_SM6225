package id.seiran.app

import android.app.LocaleManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.LocaleList
import java.util.Locale

// In-app language choice. Translations are bundled as res/values-xx/strings.xml.
// To add a language: add its tag to TAGS and add res/values-xx/strings.xml.
object LocaleHelper {
    private const val PREFS = "seiran_locale"
    private const val KEY = "language"

    // Empty tag = follow the system language.
    const val FOLLOW_SYSTEM = ""

    val TAGS: List<String> = listOf("en")

    private fun saved(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, FOLLOW_SYSTEM)
            ?: FOLLOW_SYSTEM

    fun current(context: Context): String {
        if (Build.VERSION.SDK_INT >= 33) {
            val l = context.getSystemService(LocaleManager::class.java).applicationLocales
            return if (l.isEmpty) FOLLOW_SYSTEM else l[0].toLanguageTag()
        }
        return saved(context)
    }

    fun set(context: Context, tag: String) {
        if (Build.VERSION.SDK_INT >= 33) {
            context.getSystemService(LocaleManager::class.java).applicationLocales =
                if (tag.isEmpty()) LocaleList.getEmptyLocaleList() else LocaleList.forLanguageTags(tag)
            return
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, tag).apply()
    }

    // Android 12 and below: apply the saved choice to the activity's resources.
    fun wrap(base: Context): Context {
        if (Build.VERSION.SDK_INT >= 33) return base
        val tag = saved(base)
        if (tag.isEmpty()) return base
        val config = Configuration(base.resources.configuration)
        config.setLocale(Locale.forLanguageTag(tag))
        return base.createConfigurationContext(config)
    }

    // Name of a language in that language, e.g. "Deutsch", "Espanol".
    fun displayName(tag: String): String {
        val l = Locale.forLanguageTag(tag)
        return l.getDisplayName(l).replaceFirstChar { it.titlecase(l) }
    }
}
