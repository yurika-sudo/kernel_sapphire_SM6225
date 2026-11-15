package id.seiran.app

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Build
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp

private fun Context.findActivity(): Activity? {
    var c = this
    while (c is ContextWrapper) {
        if (c is Activity) return c
        c = c.baseContext
    }
    return null
}

@Composable
fun LanguageCard() {
    val ctx = LocalContext.current
    var open by remember { mutableStateOf(false) }
    var current by remember { mutableStateOf(LocaleHelper.current(ctx)) }
    val systemLabel = stringResource(R.string.language_follow_system)
    fun label(tag: String) = if (tag.isEmpty()) systemLabel else LocaleHelper.displayName(tag)

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
        ),
    ) {
        Box {
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable { open = true }
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        stringResource(R.string.language_title),
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Text(
                        stringResource(R.string.language_sub),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(
                    label(current),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                (listOf(LocaleHelper.FOLLOW_SYSTEM) + LocaleHelper.TAGS).forEach { tag ->
                    DropdownMenuItem(
                        text = { Text(label(tag)) },
                        onClick = {
                            open = false
                            if (tag != current) {
                                current = tag
                                LocaleHelper.set(ctx, tag)
                                // Android 13+ restarts the activity by itself.
                                if (Build.VERSION.SDK_INT < 33) ctx.findActivity()?.recreate()
                            }
                        },
                    )
                }
            }
        }
    }
}
