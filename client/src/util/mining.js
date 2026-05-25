// Tracks the timestamp of the previous Thinminerpro "Computing nonces" line
// so a GPU hash-rate can be derived from the gap between two batches.
let lastNonceTime = null

// Accepted-share counters, reset on every (re)start of mining.
let cpuAcceptedCount = 0
let gpuAcceptedCount = 0

// getShareEvent parses a single miner log line and returns
// `{ kind: 'cpu' | 'gpu', accepted: true/false, count: <total accepted for that kind> }`
// or null if the line doesn't carry share info.
//
// Formats it recognises:
//   - XMRig (CPU):       `accepted (N/M ...)`            (N = total accepted so far)
//   - kawpow-mac (GPU):  `[share] accepted`
//   - kawpow-mac (GPU):  `[share] rejected: <reason>`
export function getShareEvent(log = '') {
  log = (log || '').trim()
  if (!log) return null

  // XMRig "accepted (N/M ...)" — N is the running accepted count from XMRig itself,
  // so we trust XMRig's number directly rather than incrementing locally.
  const xm = /accepted\s+\((\d+)\/\d+/i.exec(log)
  if (xm && /xmrig|miner|cpu/i.test(log) === false) {
    // Fallback only when not obviously XMRig — but XMRig lines do contain "miner"/"cpu"
  }
  if (xm) {
    const n = Number(xm[1])
    if (!Number.isNaN(n)) {
      cpuAcceptedCount = n
      return { kind: 'cpu', accepted: true, count: cpuAcceptedCount }
    }
  }

  // kawpow-mac tagged line
  if (/\[share\]\s+accepted/i.test(log)) {
    gpuAcceptedCount += 1
    return { kind: 'gpu', accepted: true, count: gpuAcceptedCount }
  }
  if (/\[share\]\s+rejected/i.test(log)) {
    return { kind: 'gpu', accepted: false, count: gpuAcceptedCount }
  }
  return null
}

export function resetShareCounts() {
  cpuAcceptedCount = 0
  gpuAcceptedCount = 0
}

// getHashrate parses a single miner log line and returns
// `{ kind: 'cpu' | 'gpu', value }` (value in H/s), or null if the line
// carries no rate information.
export function getHashrate(log = '') {
  log = (log || '').trim()
  if (!log) return null

  // XMRig (CPU / RandomX):
  // [time] miner speed 10s/60s/15m 353.6 n/a n/a H/s max 359.0 H/s
  if (/miner/.test(log) && /speed/.test(log)) {
    // "speed 10s/60s/15m 662.9 n/a n/a H/s max ..." — token [0] is the
    // "10s/60s/15m" label; token [1] is the 10-second hash-rate.
    const m = /speed(.*)max/.exec(log)
    if (m) {
      const n = Number(m[1].trim().split(/\s+/)[1])
      if (!Number.isNaN(n)) return { kind: 'cpu', value: n }
    }
    return null
  }

  // Thinminerpro (GPU / KawPow) prints no speed line. It logs one line per
  // batch: "Computing <N> nonces starting at <X> <YYYY-MM-DD HH:MM:SS> +0000".
  // The rate is the batch size divided by the time since the previous batch.
  const tm = /Computing\s+(\d+)\s+nonces.*?(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/.exec(
    log,
  )
  if (tm) {
    const nonces = Number(tm[1])
    const t = new Date(tm[2].replace(' ', 'T') + 'Z').getTime()
    let rate = null
    if (lastNonceTime != null) {
      const dt = (t - lastNonceTime) / 1000
      if (dt > 0 && dt < 120) rate = nonces / dt
    }
    lastNonceTime = t
    return rate != null ? { kind: 'gpu', value: rate } : null
  }

  return null
}

// resetHashrate clears the GPU rate state. Call it when mining (re)starts so
// a stale timestamp from a previous run does not skew the first reading.
export function resetHashrate() {
  lastNonceTime = null
}

// formatHashrate turns a H/s number into a short human-readable string.
export function formatHashrate(hs) {
  if (!hs || Number.isNaN(hs)) return '0 H/s'
  if (hs >= 1e9) return (hs / 1e9).toFixed(2) + ' GH/s'
  if (hs >= 1e6) return (hs / 1e6).toFixed(2) + ' MH/s'
  if (hs >= 1e3) return (hs / 1e3).toFixed(2) + ' kH/s'
  return hs.toFixed(0) + ' H/s'
}
