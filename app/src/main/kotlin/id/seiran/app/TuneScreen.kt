@file:OptIn(
    androidx.compose.material3.ExperimentalMaterial3Api::class,
    androidx.compose.foundation.layout.ExperimentalLayoutApi::class,
)

package id.seiran.app

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlin.concurrent.thread

@Composable
fun TuneScreen() {
    var st by remember { mutableStateOf<TuneState?>(null) }
    var msg by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    var zp by remember { mutableStateOf<ZramPrimary?>(null) }
    LaunchedEffect(Unit) { thread { st = Tune.load(); zp = TuneZram.load() } }

    fun act(block: () -> Boolean) {
        if (busy) return
        busy = true
        msg = null
        TuneZram.err = null
        thread {
            val ok = block()
            msg = if (ok) null else (TuneZram.err ?: "Could not apply that setting")
            st = Tune.load()
            zp = TuneZram.load()
            busy = false
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .statusBarsPadding()
            .padding(horizontal = 16.dp)
            .padding(bottom = 104.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            "Tune",
            style = MaterialTheme.typography.displaySmall,
            modifier = Modifier.padding(top = 16.dp, start = 4.dp),
        )
        if (busy) androidx.compose.material3.LinearProgressIndicator(Modifier.fillMaxWidth())
        msg?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        val s = st
        if (s == null) {
            Text("Loading...", color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else {
            Group("cpufreq governor", "Applies now (policy0 + policy4)", s.cpufreq, s.cpufreqNow) { g ->
                act { Tune.setCpufreq(g, s.cpufreq) }
            }
            Group("cpuidle governor", "Applies now", s.cpuidle, s.cpuidleNow) { g ->
                act { Tune.setCpuidle(g, s.cpuidle) }
            }
            Group("I/O scheduler", "Applies now (all sd* disks)", s.io, s.ioNow) { g ->
                act { Tune.setIo(g, s.io) }
            }
            Group(
                "zram recompress algo",
                "Applies after reboot (active: ${s.recompNow ?: "-"})",
                s.recomp,
                s.recompSaved ?: s.recompNow,
                badge = if (s.recompSaved != null && s.recompSaved != s.recompNow) "Pending reboot" else null,
            ) { a -> act { Tune.setRecomp(a, s.recomp) } }
            zp?.let { z ->
                Group(
                    "zram primary algo",
                    "Applies now: swap is rebuilt, takes a few seconds",
                    z.list,
                    z.now,
                ) { a -> act { TuneZram.setPrimary(a, z.list) } }
            }
        }
    }
}

@Composable
private fun Group(
    title: String,
    note: String,
    options: List<String>,
    current: String?,
    badge: String? = null,
    onPick: (String) -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
        ),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                if (badge != null) {
                    androidx.compose.material3.Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = MaterialTheme.colorScheme.tertiaryContainer,
                    ) {
                        Text(
                            badge,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onTertiaryContainer,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                        )
                    }
                }
            }
            Text(
                note,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            androidx.compose.foundation.layout.FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                options.forEach { o ->
                    FilterChip(selected = o == current, onClick = { onPick(o) }, label = { Text(o) })
                }
            }
        }
    }
}
