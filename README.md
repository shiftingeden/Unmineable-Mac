> 🛠️ This is a maintained fork of [2nthony/macmineable](https://github.com/2nthony/macmineable),
> which the original author stopped developing after switching to an M1 Mac
> ("can not connect to unmineable server"). This fork upgrades XMRig and adds a
> selectable GPU miner — see [Miners](#miners) below.

# macMineable (unMineable for macOS)

![](https://img.shields.io/github/v/release/2nthony/macmineable?label=)
![](https://img.shields.io/github/downloads/2nthony/macmineable/total)

<a href="https://www.producthunt.com/posts/macmineable?utm_source=badge-featured&utm_medium=badge&utm_souce=badge-macmineable" target="_blank"><img src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=305377&theme=light" alt="macMineable - unMineable for macOS, 3rd-party. | Product Hunt" style="width: 250px; height: 54px;" width="250" height="54" /></a>

_macOS 11 or above_

## Introduction

macMineable is the unMineable 3rd-party app that can let you mining cryptocurrency on macOS with ease.

## Sponsor

**[Don Café](https://don-cafe.aotunote.com) - A web-widget to collect your all donation links in one button.**

## Highlights

- [x] **unMineable UI flavoured**
- [x] Written in Go and Svelte
- [x] Dark mode
- [x] Selectable CPU **and** GPU miners
- [x] Fast and lite
- [x] All unMineable coins are supported
- [x] Tweak CPU usage for mining
- [x] Check new release available
- [x] Form memorize
- [x] Log reporter

## Miners

macMineable can mine with either of two backends, chosen with the **CPU / GPU
toggle** on the mining screen:

| Backend | Type | Algorithm | unMineable pool |
| --- | --- | --- | --- |
| [XMRig](https://github.com/xmrig/xmrig) `6.26.0` | CPU | RandomX | `rx.unmineable.com` |
| [Thinminerpro](https://github.com/rezahussain/thinminerpro) | GPU (Metal) | KawPow | `kp.unmineable.com` |

RandomX is CPU-only by design, so GPU mining uses a different algorithm
(KawPow) via Thinminerpro, which runs on the Apple Silicon GPU through Metal.
Use the toggle to compare hashrate and rewards between the two on your machine.

> ⚠️ Mining on a Mac is generally not profitable and runs the chips hot. Treat
> this as something to experiment with on hardware you already own.

### Fetching the miner binaries

The miner binaries are **not** committed to this repo. Fetch them before
building:

```sh
npm run fetch:miners
```

This downloads XMRig (`6.26.0`, Intel + Apple Silicon) and Thinminerpro into
`assets/miner/`.

### About the original "can not connect" bug

The original app shipped XMRig `6.17.0` (built April 2022). That stale build
fails on current Apple Silicon macOS — the RandomX JIT and hardened-runtime
behaviour changed in later XMRig releases. Upgrading to XMRig `6.26.0` is the
primary fix; this fork also surfaces miner `stderr` in the log drawer so launch
failures are visible. Verify on your own Mac.

## Build from source

```sh
npm install
npm run fetch:miners   # download miner binaries into assets/miner/
npm run build:app      # build the Svelte UI + Go app into out/
```

## Download

Download in [Releases page](https://github.com/2nthony/macmineable/releases).

## Notices

Since `v0.10.0` you need to read [this release](https://github.com/2nthony/macmineable/releases/tag/v0.10.0).

We create a webserver with the host `127.0.0.1:47261` to render the UI, so make sure this host is not occupied.

### Tested devices

- Macbook Pro 2015 with Intel I5 chip, big sur 11.5.2
- Macbook 12-inch with Intel M-5Y31 chip, big sur 11.1
- Thanks to [@yoobanz](https://twitter.com/yoobandz) helping me tested on M1 device. https://twitter.com/yoobandz/status/1430951939177603079

### Issues

When you have issues with running, read these below may help:

<details><summary>"xmrig" cannot be opened because the developer can not be verified.</summary>

![](https://cdn.jsdelivr.net/gh/2nthony/statics@main/uPic/Wp0a7nt8ebm9.jpg)
![](https://cdn.jsdelivr.net/gh/2nthony/statics@main/uPic/RKucH35GQxQl.jpg)
![](https://cdn.jsdelivr.net/gh/2nthony/statics@main/uPic/YkYIDNGJTmnE.jpg)

</details>

### Don't quit the app is mining

Press the `Stop` button first. If you did, read [this](https://github.com/2nthony/macmineable/issues/10).

## Sponsors

[![sponsors](https://cdn.jsdelivr.net/gh/2nthony/sponsors-image/sponsors.svg)](https://github.com/sponsors/2nthony)

## LICENSE

GNU GPL v3 © [2nthony](https://github.com/2nthony).
