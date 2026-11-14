package id.seiran.app

// UFS life_time_estimation: 0x01..0x0A = used per 10% step, 0x0B = past rated life
fun ufsLife(raw: String?): String? {
    val v = raw?.trim()?.removePrefix("0x")?.toIntOrNull(16) ?: return null
    return when (v) {
        in 1..10 -> "${(10 - v) * 10}-${(11 - v) * 10}%"
        11 -> "past limit"
        else -> null
    }
}
