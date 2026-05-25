package lib

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// MinerForm carries the user-provided mining parameters that are shared
// across every supported miner backend.
type MinerForm struct {
	Miner        string // "xmrig" (CPU/RandomX) | "thinminerpro" (GPU/KawPow)
	MinerName    string // worker name shown on the unMineable dashboard
	Symbol       string
	Address      string
	ReferralCode string
	CPUUsage     int
}

// sanitizeWorker keeps only characters that are safe both as an unMineable
// worker name and as part of a shell argument.
func sanitizeWorker(s string) string {
	var b strings.Builder
	for _, r := range s {
		if (r >= 'a' && r <= 'z') ||
			(r >= 'A' && r <= 'Z') ||
			(r >= '0' && r <= '9') ||
			r == '-' || r == '_' {
			b.WriteRune(r)
		}
	}
	return b.String()
}

// unmineableUser identifies a worker with the pattern:
//
//	COIN:ADDRESS.WORKER#REFERRAL
//
// The worker name comes from the user's "Miner name" setting and shows up in
// the unMineable dashboard; it falls back to "UnmineableMac".
func unmineableUser(f MinerForm) string {
	worker := sanitizeWorker(f.MinerName)
	if worker == "" {
		worker = "UnmineableMac"
	}
	return fmt.Sprintf("%s:%s.%s#%s", f.Symbol, f.Address, worker, f.ReferralCode)
}

// minerAssetDir is the directory that holds the bundled miner binaries.
// main.go chdir's into the app's "Resources" directory at launch, so a path
// relative to the working directory resolves correctly both for the packaged
// .app and for `go run` from the repo root during development.
func minerAssetDir() string {
	return filepath.Join("assets", "miner")
}

// ---------------------------------------------------------------------------
// XMRig — CPU mining on unMineable's RandomX pool.
// ---------------------------------------------------------------------------

// xmrigBinary picks the XMRig build for the current CPU architecture.
// Apple Silicon uses the arm64 build; Intel Macs use the x86_64 build.
func xmrigBinary() string {
	name := "xmrig-m1"
	if IsIntel() {
		name = "xmrig"
	}
	return filepath.Join(minerAssetDir(), name)
}

// buildXMRigCommand returns the shell command that runs XMRig against
// unMineable's RandomX (CPU) pool.
func buildXMRigCommand(f MinerForm) string {
	// --print-time=5 makes XMRig print its hashrate summary every 5s (default
	// is 60s) so the UI hashrate updates quickly.
	return fmt.Sprintf(
		`"%s" --no-color --print-time=5 --url=rx.unmineable.com:3333 --algo=rx --pass=x --keepalive --user=%s --cpu-max-threads-hint=%d`,
		xmrigBinary(),
		unmineableUser(f),
		f.CPUUsage,
	)
}

// ---------------------------------------------------------------------------
// Thinminerpro — GPU mining (Metal) on unMineable's KawPow pool.
//
// Thinminerpro is config-file driven rather than CLI-flag driven: it reads a
// config.json sitting next to the binary and must be launched from its own
// directory. We patch that config.json with the user's unMineable worker
// string before launching.
//
// The shipped config.json looks like:
//
//	{
//	  "user": "RVN:<address>.<worker>",
//	  "chosenURL": "ethash.unmineable.com",
//	  "chosenPort": 3333,
//	  "deviceNumber": 0,
//	  "intensity": 10371840
//	}
//
// patchThinminerproConfig only rewrites the worker/pool keys and preserves
// everything else (deviceNumber, intensity, ...).
// ---------------------------------------------------------------------------

// thinminerproDir is the per-architecture directory holding the Thinminerpro
// binary together with all of its resources (config.json, Metal shader
// library, ...). scripts/fetchMiners.sh copies each release folder whole.
func thinminerproDir() string {
	name := "thinminerpro"
	if IsIntel() {
		name = "thinminerpro-intel"
	}
	return filepath.Join(minerAssetDir(), name)
}

// patchThinminerproConfig writes the user's unMineable worker string (and a
// default KawPow pool host, if none is already configured) into the
// Thinminerpro config.json. Unknown keys in the shipped config are preserved.
func patchThinminerproConfig(dir string, f MinerForm) error {
	path := filepath.Join(dir, "config.json")

	cfg := map[string]interface{}{}
	if raw, err := os.ReadFile(path); err == nil {
		// Ignore a parse error: fall back to a fresh config.
		_ = json.Unmarshal(raw, &cfg)
	}

	// Worker identity (unMineable-style: COIN:ADDRESS.WORKER#REFERRAL).
	cfg["user"] = unmineableUser(f)

	// Ensure the unMineable KawPow pool is configured. Thinminerpro's
	// config.json uses the keys "chosenURL" / "chosenPort".
	// NOTE: unMineable's KawPow/ProgPoW pool hostname is `ethash.unmineable.com`
	// (the `kp.unmineable.com` host that older Thinminerpro releases shipped
	// returns validation errors — see https://github.com/shiftingeden/kawpow-mac
	// for the debug history).
	if _, ok := cfg["chosenURL"]; !ok {
		cfg["chosenURL"] = "ethash.unmineable.com"
	}
	if _, ok := cfg["chosenPort"]; !ok {
		cfg["chosenPort"] = 3333
	}

	out, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, out, 0644)
}

// buildThinminerproCommand patches the config and returns the command that
// launches Thinminerpro plus the working directory it must run in.
func buildThinminerproCommand(f MinerForm) (cmd string, dir string, err error) {
	dir = thinminerproDir()

	if _, statErr := os.Stat(filepath.Join(dir, "thinminerpro")); statErr != nil {
		return "", "", fmt.Errorf(
			"Thinminerpro not found in %s — run scripts/fetchMiners.sh first",
			dir,
		)
	}

	if patchErr := patchThinminerproConfig(dir, f); patchErr != nil {
		return "", "", fmt.Errorf("failed to write Thinminerpro config: %v", patchErr)
	}

	abs, absErr := filepath.Abs(dir)
	if absErr != nil {
		abs = dir
	}

	// Run the binary directly (no `cd ... && ...`). A single-command shell
	// exec()s into the miner, so the tracked PID is the miner itself and Stop
	// can kill it. The working directory is applied by the caller via
	// exec.Cmd.Dir, which is also where Thinminerpro finds config.json and its
	// Metal shader resources.
	return "./thinminerpro", abs, nil
}

// ---------------------------------------------------------------------------
// Dispatch
// ---------------------------------------------------------------------------

// BuildMinerCommand returns the shell command for the selected miner and the
// working directory it should run in ("" = inherit). Defaults to XMRig (CPU).
func BuildMinerCommand(f MinerForm) (cmd string, dir string, err error) {
	switch f.Miner {
	case "thinminerpro":
		return buildThinminerproCommand(f)
	case "xmrig", "":
		return buildXMRigCommand(f), "", nil
	default:
		return "", "", fmt.Errorf("unknown miner: %q", f.Miner)
	}
}
