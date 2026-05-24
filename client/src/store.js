import { writable } from '@svelte-use/shared'

export const form = writable({
  // miners — either or both may run at the same time
  cpuEnabled: true,
  gpuEnabled: false,
  // worker names shown on the unMineable dashboard — one per miner
  cpuMinerName: 'UnmineableMac-CPU',
  gpuMinerName: 'UnmineableMac-GPU',
  symbol: '',
  address: '',
  referralCode: '',
  cpuUsage: 25,
})

export const preparing = writable(false)

export const isMining = writable(false)

// current hash-rate (H/s) for each miner backend
export const cpuHashrate = writable(0)
export const gpuHashrate = writable(0)

// system load as percentages; -1 means "unknown"
export const utilization = writable({ cpu: -1, gpu: -1 })

// calculated in `FormSettings.svelte`
export const cpuCores = writable(100)

// true on Apple Silicon Macs; GPU mining is only supported there
export const appleSilicon = writable(true)

export const miningLogs = writable([])
