# Unmineable-Mac

> 🛠️ A maintained fork of [2nthony/macmineable](https://github.com/2nthony/macmineable).
> The original author stopped developing it after switching to an M1 Mac
> ("can not connect to unmineable server"). This fork revives it: upgraded
> XMRig, a selectable GPU miner, faster hashrate readout, and a cleaner UI.

_macOS 11 or above_

## Download

Pre-built apps for macOS 12+ — no build required:

- **[⬇ Apple Silicon (M1 – M5+)](https://github.com/shiftingeden/Unmineable-Mac/releases/latest)** → `Unmineable-Mac-*-AppleSilicon.zip` — full GPU + CPU mining via the in-repo open-source [kawpow-mac](https://github.com/shiftingeden/kawpow-mac).
- **[⬇ Intel Mac](https://github.com/shiftingeden/Unmineable-Mac/releases/latest)** → `Unmineable-Mac-*-Intel.zip` — CPU mining (XMRig); GPU is best-effort via the legacy upstream Thinminerpro.

First launch: right-click → Open (the app is ad-hoc signed, not notarized — Gatekeeper asks for confirmation the first time).

## Introduction

Unmineable-Mac is a 3rd-party [unMineable](https://unmineable.com) client for
macOS — it lets you mine cryptocurrency on your Mac through a simple UI. It is
not affiliated with unMineable.

## Screenshots

<p>
  <img src="screenshots/setup.png" width="250" alt="Coin and address setup" />
  <img src="screenshots/mining.png" width="250" alt="Mining screen" />
  <img src="screenshots/mining-log.png" width="250" alt="Mining with live log" />
  <img src="screenshots/settings.png" width="250" alt="Settings" />
</p>

## Highlights

- [x] unMineable-flavoured UI, written in Go and Svelte
- [x] **Selectable CPU and GPU miners** — switch with one toggle
- [x] XMRig `6.26.0` for CPU mining (RandomX)
- [x] In-repo **kawpow-mac** miner for GPU mining (KawPow / Metal) on Apple Silicon — open-source replacement for Thinminerpro
- [x] Dark mode
- [x] All unMineable coins supported
- [x] Tweak CPU usage for mining
- [x] Live hashrate, balance, and an optional in-app log panel
- [x] Form memory and update check

## Miners

Unmineable-Mac can mine with either backend — or **both at the same time** —
using the CPU / GPU checkboxes on the mining screen:

| Backend | Type | Algorithm | unMineable pool | Requires |
| --- | --- | --- | --- | --- |
| [XMRig](https://github.com/xmrig/xmrig) `6.26.0` | CPU | RandomX | `rx.unmineable.com` | Any Mac |
| **kawpow-mac** (in-repo) | GPU (Metal) | KawPow | `kp.unmineable.com` | **Apple Silicon** |
| [Thinminerpro](https://github.com/rezahussain/thinminerpro) | GPU (Metal) | KawPow | `kp.unmineable.com` | Intel (fallback) |

RandomX is CPU-only by design, so GPU mining uses a different algorithm
(KawPow). On Apple Silicon we build our own KawPow miner from source
([kawpow-mac/](kawpow-mac/)) — Thinminerpro is closed-source and does not
submit accepted shares on M3+ chips. On Intel Macs we still fall back to
the upstream Thinminerpro binary.

> ✅ **GPU mining works on modern Apple Silicon (M3+) via `kawpow-mac`.**
> First open-source KawPow miner verified accepted by the unMineable
> pool on these chips (closed-source upstream Thinminerpro doesn't
> submit accepted shares here). See
> [kawpow-mac/BUGS_AND_FIXES.md](kawpow-mac/BUGS_AND_FIXES.md) for the
> chronicle of five algorithmic bugs that had to be uncovered along the
> way.

> ⚠️ **GPU mining requires an Apple Silicon Mac (M-series).** Intel Macs
> can only use the CPU miner (XMRig).

> ⚠️ Mining on a Mac is generally not profitable and runs the chips hot. Treat
> this as something to experiment with on hardware you already own.

### Fetching the miner binaries

The miner binaries are **not** committed to this repo. Fetch them before
building:

```sh
npm run fetch:miners
```

This downloads XMRig (`6.26.0`, Intel + Apple Silicon) and the Intel
Thinminerpro fallback, **and builds the in-repo kawpow-mac GPU miner from
source** (`swift build -c release`), installing it into `assets/miner/`.

Requires a Swift toolchain (Xcode Command Line Tools).

## Build from source

```sh
npm install
npm run fetch:miners
npm run build:app
```

- `npm run fetch:miners` downloads XMRig and the Intel Thinminerpro
  fallback into `assets/miner/`, and clones + builds `kawpow-mac` from
  source for Apple Silicon GPU mining.
- `npm run build:app` builds the Svelte UI + Go app into `out/`.

The built `Unmineable-Mac.app` lands in `out/`.

## What changed in this fork

- Upgraded XMRig `6.17.0` → `6.26.0` — the stale build was the cause of the
  original "can not connect" failure on Apple Silicon
- Added a **CPU / GPU miner toggle** on the mining screen
- Added **Thinminerpro** (GPU / KawPow via Metal) for Apple Silicon — later
  replaced by our in-repo **kawpow-mac** miner (Swift + Metal, open source)
  because upstream Thinminerpro is closed-source and does not submit
  accepted shares on M3+ Apple Silicon
- Faster hashrate updates — XMRig reports every 5s, and a GPU hashrate is
  derived from the miner's `Computing <N> nonces` output
- Bigger, **resizable** window with an optional inline **live-log panel**
- Miner `stderr` is surfaced in the logs so launch failures are visible
- Replaced "Buy Me a Coffee" with a **Donate** button (Litecoin)
- Removed the promotion banner and sponsor sections
- Rebranded to **Unmineable-Mac**

## Notices

The app runs a local webserver on `127.0.0.1:47261` to render the UI — make
sure that host/port is free.

Press **Stop** before quitting while mining, so the miner process is shut
down cleanly.

Miner binaries are unsigned third-party software; `fetchMiners.sh` clears the
macOS quarantine flag, but Gatekeeper may still prompt on first launch — allow
them in System Settings if needed.

## LICENSE

GNU GPL v3. Originally © [2nthony](https://github.com/2nthony); this fork is
maintained by [shiftingeden](https://github.com/shiftingeden).

As a derivative of GPL-v3 software, this fork **must** remain under GPL v3 —
that is a requirement of the license, so the `LICENSE` file stays in place.
