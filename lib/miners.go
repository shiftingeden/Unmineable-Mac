package lib

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// MinerForm carries the user-provided mining parameters that are shared
// across every supported miner backend.
type MinerForm struct {
	Miner        string // "xmrig" (CPU/RandomX) | "thinminerpro" (GPU/KawPow)
	Symbol       string
	Address      string
	ReferralCode string
	CPUUsage     int
}

// unMineable identifies a worker with the pattern:
//
//	COIN:ADDRESS.WORKER#REFERRAL
//
// The "macMineable" worker name is kept for backwards compatibility with the
// stats the original app reported.
func unmineableUser(f MinerForm) string {
	return fmt.Sprintf("%s:%s.macMineable#%s", f.Symbol, f.Address, f.ReferralCode)
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
	return fmt.Sprintf(
		`"%s" --no-color --url=rx.unmineable.com:3333 --algo=rx --pass=x --keepalive --user=%s --cpu-max-threads-hint=%d`,
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
// directory. We patch the config.json with the user's unMineable worker
// string before launching.
//
// NOTE: Thinminerpro's exact config.json schema is not formally documented.
// patchThinminerproConfig preserves any keys already present in the shipped
// config and only sets the worker/pool keys, so it stays correct even if the
// shipped schema differs. Verify against the real config.json after running
// scripts/fetchMiners.sh.
// ---------------------------------------------------------------------------

func thinminerproDir() string {
	return filepath.Join(minerAssetDir(), "thinminerpro")
}

func thinminerproBinary() string {
	if IsIntel() {
		return "thinminerpro-intel"
	}
	return "thinminerpro"
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

	// Worker identity. Thinminerpro's README documents this key as "user".
	cfg["user"] = unmineableUser(f)

	// Point at unMineable's KawPow pool only if the shipped config does not
	// already define a pool endpoint.
	_, hasHost := cfg["host"]
	_, hasURL := cfg["url"]
	if !hasHost && !hasURL {
		cfg["host"] = "kawpow.unmineable.com"
		cfg["port"] = 3333
	}

	out, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, out, 0644)
}

// buildThinminerproCommand patches the config and returns the shell command
// that launches Thinminerpro from its own directory.
func buildThinminerproCommand(f MinerForm) (string, error) {
	dir := thinminerproDir()

	if _, err := os.Stat(filepath.Join(dir, thinminerproBinary())); err != nil {
		return "", fmt.Errorf(
			"Thinminerpro binary not found in %s — run scripts/fetchMiners.sh first",
			dir,
		)
	}

	if err := patchThinminerproConfig(dir, f); err != nil {
		return "", fmt.Errorf("failed to write Thinminerpro config: %v", err)
	}

	abs, err := filepath.Abs(dir)
	if err != nil {
		abs = dir
	}

	// Thinminerpro must run with its directory as the working directory so it
	// can find config.json and its Metal shader resources.
	return fmt.Sprintf(`cd "%s" && "./%s"`, abs, thinminerproBinary()), nil
}

// ---------------------------------------------------------------------------
// Dispatch
// ---------------------------------------------------------------------------

// BuildMinerCommand returns the shell command for the miner selected in the
// form. It defaults to XMRig (CPU) when no miner is specified.
func BuildMinerCommand(f MinerForm) (string, error) {
	switch f.Miner {
	case "thinminerpro":
		return buildThinminerproCommand(f)
	case "xmrig", "":
		return buildXMRigCommand(f), nil
	default:
		return "", fmt.Errorf("unknown miner: %q", f.Miner)
	}
}
