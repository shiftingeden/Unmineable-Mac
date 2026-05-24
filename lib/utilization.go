package lib

import (
	"os/exec"
	"runtime"
	"strconv"
	"strings"
)

// SampleUtilization returns CPU and GPU load as whole percentages (0-100).
// A value of -1 means the metric could not be read on this machine.
//
// Both samplers are intentionally lightweight (a quick `ps` / `ioreg`), so
// the UI can poll them on an interval without measurably affecting mining.
func SampleUtilization() (cpu int, gpu int) {
	return sampleCPU(), sampleGPU()
}

// sampleCPU sums the per-process %CPU reported by `ps` and divides by the
// core count to get an overall load figure. `ps` reports a short decaying
// average, which is fine for the steady load that mining produces.
func sampleCPU() int {
	out, err := exec.Command("bash", "-c",
		`ps -A -o %cpu= | awk '{s += $1} END {print s}'`).Output()
	if err != nil {
		return -1
	}

	total, err := strconv.ParseFloat(strings.TrimSpace(string(out)), 64)
	if err != nil {
		return -1
	}

	cores := runtime.NumCPU()
	if cores < 1 {
		cores = 1
	}

	used := total / float64(cores)
	if used < 0 {
		used = 0
	}
	if used > 100 {
		used = 100
	}
	return int(used + 0.5)
}

// sampleGPU reads the Apple Silicon GPU load from IOKit: the accelerator's
// PerformanceStatistics dictionary exposes a "Device Utilization %" entry.
// This is best-effort — if the entry is not present it returns -1.
func sampleGPU() int {
	out, err := exec.Command("bash", "-c",
		`ioreg -r -d 1 -w 0 -c IOAccelerator 2>/dev/null | grep -o '"Device Utilization %"=[0-9]*' | head -1`).Output()
	if err != nil {
		return -1
	}

	s := strings.TrimSpace(string(out))
	i := strings.LastIndex(s, "=")
	if i < 0 {
		return -1
	}

	v, err := strconv.Atoi(strings.TrimSpace(s[i+1:]))
	if err != nil {
		return -1
	}
	return v
}
