package id.seiran.app

import com.topjohnwu.superuser.Shell

data class ZramPrimary(val list: List<String>, val now: String?)

object TuneZram {
    private const val DIR = "/data/adb/seiran"
    private const val Z = "/sys/block/zram0"
    private const val D = "/dev/block/zram0"
    private const val MARGIN_KB = 262144L
    private val safe = Regex("^[A-Za-z0-9_.-]+$")

    @Volatile var err: String? = null

    private fun fail(m: String): Boolean {
        err = m
        return false
    }

    fun load(): ZramPrimary {
        val raw = Sys.read("$Z/comp_algorithm", true)
        val list = (raw ?: "").replace("[", " ").replace("]", " ")
            .split(Regex("\\s+")).filter { safe.matches(it) }.distinct()
        return ZramPrimary(list, Sys.active(raw))
    }

    private fun kb(key: String): Long? =
        Sys.read("/proc/meminfo", true)?.lineSequence()
            ?.firstOrNull { it.startsWith("$key:") }
            ?.split(Regex("\\s+"))?.getOrNull(1)?.toLongOrNull()

    // /proc/swaps columns: Filename Type Size Used Priority
    private fun swapUsedKb(): Long =
        Sys.read("/proc/swaps", true)?.lineSequence()
            ?.firstOrNull { it.contains("zram0") }
            ?.split(Regex("\\s+"))?.getOrNull(3)?.toLongOrNull() ?: 0L

    // comp_algorithm only changes on an uninitialised device (-EBUSY otherwise):
    // swapoff, reset, set algo, disksize, mkswap, swapon. swapon always runs last.
    fun setPrimary(a: String, list: List<String>): Boolean {
        if (a !in list || !safe.matches(a)) return false
        val now = Sys.active(Sys.read("$Z/comp_algorithm", true))
        if (a == now) return true

        val avail = kb("MemAvailable") ?: return fail("Cannot read MemAvailable")
        val need = swapUsedKb() + MARGIN_KB
        if (avail < need) {
            return fail("Not enough free RAM: need ${need / 1024} MB, have ${avail / 1024} MB")
        }

        val curSize = Sys.read("$Z/disksize", true)?.takeIf { safe.matches(it) } ?: "2G"
        val r = Sys.read("$DIR/zram_recomp", true)?.takeIf { safe.matches(it) }
            ?: Sys.active(Sys.read("$Z/recomp_algorithm", true))?.takeIf { safe.matches(it) }
        val rc = if (r != null) "echo \"algo=$r priority=1\" > $Z/recomp_algorithm && " else ""

        val off = Shell.cmd("if grep -q -E '^/dev/(block/)?zram0([[:space:]]|$)' /proc/swaps; then swapoff $D; fi").exec()
        if (!off.isSuccess) {
            return fail("swapoff failed: memory constrained or device busy")
        }

        Shell.cmd(
            "echo 1 > $Z/reset && { echo $a > $Z/comp_algorithm || true; } && " +
                "${rc}echo $curSize > $Z/disksize && mkswap $D; swapon $D",
        ).exec()

        val after = Sys.active(Sys.read("$Z/comp_algorithm", true))
        val swapOn = Sys.read("/proc/swaps", true)?.contains("zram0") == true
        if (after != a) {
            return fail("Switch failed (active: ${after ?: "?"})")
        }
        if (!swapOn) {
            return fail("Switched to $a, but swap is off. Check: cat /proc/swaps")
        }

        Shell.cmd("mkdir -p $DIR", "echo $a > $DIR/zram_comp").exec()
        return true
    }
}
