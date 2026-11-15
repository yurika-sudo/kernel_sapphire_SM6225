package id.seiran.app

import com.topjohnwu.superuser.Shell

data class TuneState(
    val cpufreq: List<String>,
    val cpufreqNow: String?,
    val cpuidle: List<String>,
    val cpuidleNow: String?,
    val io: List<String>,
    val ioNow: String?,
    val recomp: List<String>,
    val recompNow: String?,
    val recompSaved: String?,
)

object Tune {
    private const val DIR = "/data/adb/seiran"
    private const val CPUFREQ = "/sys/devices/system/cpu/cpufreq"
    private const val CPUIDLE = "/sys/devices/system/cpu/cpuidle"
    private const val IO = "/sys/block/sda/queue/scheduler"
    private const val RECOMP = "/sys/block/zram0/recomp_algorithm"
    private val safe = Regex("^[A-Za-z0-9_.-]+$")

    private fun opts(raw: String?): List<String> =
        (raw ?: "").replace("[", " ").replace("]", " ")
            .split(Regex("\\s+")).filter { safe.matches(it) }.distinct()

    fun load(): TuneState {
        val io = Sys.read(IO, true)
        val rc = Sys.read(RECOMP, true)
        return TuneState(
            cpufreq = opts(Sys.read("$CPUFREQ/policy0/scaling_available_governors", true)),
            cpufreqNow = Sys.read("$CPUFREQ/policy0/scaling_governor", true),
            cpuidle = opts(Sys.read("$CPUIDLE/available_governors", true)),
            cpuidleNow = Sys.read("$CPUIDLE/current_governor", true),
            io = opts(io),
            ioNow = Sys.active(io),
            recomp = opts(rc),
            recompNow = Sys.active(rc),
            recompSaved = Sys.read("$DIR/zram_recomp", true),
        )
    }

    // value must be in the list read from sysfs and match the safe charset
    private fun valid(v: String, list: List<String>) = v in list && safe.matches(v)

    private fun save(name: String, v: String): Boolean =
        Shell.cmd("mkdir -p $DIR", "echo $v > $DIR/$name").exec().isSuccess

    fun setCpufreq(g: String, list: List<String>): Boolean {
        if (!valid(g, list)) return false
        Shell.cmd(
            "echo $g > $CPUFREQ/policy0/scaling_governor",
            "if [ -d $CPUFREQ/policy4 ]; then echo $g > $CPUFREQ/policy4/scaling_governor; fi",
        ).exec()
        val ok0 = Sys.read("$CPUFREQ/policy0/scaling_governor", true) == g
        val p4 = Sys.read("$CPUFREQ/policy4/scaling_governor", true)
        val ok4 = p4 == null || p4 == g
        if (ok0 && ok4) {
            save("cpufreq", g)
            return true
        }
        return false
    }

    fun setCpuidle(g: String, list: List<String>): Boolean {
        if (!valid(g, list)) return false
        Shell.cmd("echo $g > $CPUIDLE/current_governor").exec()
        val ok = Sys.read("$CPUIDLE/current_governor", true) == g
        if (ok) save("cpuidle", g)
        return ok
    }

    fun setIo(g: String, list: List<String>): Boolean {
        if (!valid(g, list)) return false
        Shell.cmd("for d in /sys/block/sd*/queue/scheduler; do echo $g > \$d; done").exec()
        val ok = Sys.active(Sys.read(IO, true)) == g
        if (ok) save("io", g)
        return ok
    }

    // zram recomp algo can't change live; applied by post-fs-data.sh at next boot
    fun setRecomp(a: String, list: List<String>): Boolean {
        if (!valid(a, list)) return false
        return save("zram_recomp", a)
    }

    // Back to the module defaults: drop every saved pick and re-apply the live
    // ones (defaults match service.sh / post-fs-data.sh). zram changes on reboot.
    fun reset(s: TuneState): Boolean {
        val ok = Shell.cmd(
            "rm -f $DIR/cpufreq $DIR/cpuidle $DIR/io $DIR/zram_comp $DIR/zram_recomp",
        ).exec().isSuccess
        if (!ok) return false
        if ("vorpal" in s.cpufreq) {
            Shell.cmd(
                "echo vorpal > $CPUFREQ/policy0/scaling_governor",
                "if [ -d $CPUFREQ/policy4 ]; then echo vorpal > $CPUFREQ/policy4/scaling_governor; fi",
            ).exec()
        }
        if ("teo" in s.cpuidle) Shell.cmd("echo teo > $CPUIDLE/current_governor").exec()
        if ("adios" in s.io) {
            Shell.cmd("for d in /sys/block/sd*/queue/scheduler; do echo adios > \$d; done").exec()
        }
        return true
    }
}
