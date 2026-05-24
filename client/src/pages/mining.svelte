<script>
  import '@shoelace-style/shoelace/dist/components/button/button'
  import '@shoelace-style/shoelace/dist/components/tooltip/tooltip'
  import { afterUpdate } from 'svelte'
  import { tryOnMount, tryOnDestroy } from '@svelte-use/core'
  import {
    form,
    isMining,
    preparing,
    miningLogs,
    cpuHashrate,
    gpuHashrate,
    utilization,
  } from '../store'
  import { getBalance } from '../server/unMineable'
  import IconRefresh from '../components/icons/Refresh.svelte'
  import TopButtons from '../components/TopButtons.svelte'
  import HashratesChart from '../components/HashratesChart.svelte'
  import Donate from '../components/Donate.svelte'
  import { ipc } from '../ipc'
  import * as router from 'svelte-spa-router'
  import { log } from '../util/log'
  import { getHashrate, formatHashrate, resetHashrate } from '../util/mining'

  let dialogLogsData = []
  miningLogs.subscribe((logs) => {
    dialogLogsData = logs

    // Both miners write to one log stream; route each line's rate by kind.
    const hr = getHashrate(logs[logs.length - 1])
    if (hr) {
      if (hr.kind === 'cpu') $cpuHashrate = hr.value
      else if (hr.kind === 'gpu') $gpuHashrate = hr.value
    }
  })

  let balance = {}
  let refreshingBalance = false

  // Inline live-log panel.
  let showLiveLog = false
  let liveLogEl
  $: liveLogText =
    dialogLogsData.slice(-400).join('\n') || 'Waiting for miner output…'

  afterUpdate(() => {
    if (showLiveLog && liveLogEl) {
      liveLogEl.scrollTop = liveLogEl.scrollHeight
    }
  })

  // CPU/GPU utilization polling.
  let utilInterval = 10
  let utilTimer

  function pollUtilization() {
    ipc.send('emitGetUtilization')
  }
  function startUtilPolling() {
    stopUtilPolling()
    pollUtilization()
    utilTimer = setInterval(
      pollUtilization,
      (Number(utilInterval) || 10) * 1000,
    )
  }
  function stopUtilPolling() {
    if (utilTimer) clearInterval(utilTimer)
    utilTimer = null
  }
  // Re-arm the timer when the interval changes (but not before mount).
  $: applyUtilInterval(utilInterval)
  function applyUtilInterval(_secs) {
    if (utilTimer) startUtilPolling()
  }

  ipc.listen('onUtilization', (cpu, gpu) => {
    $utilization = { cpu, gpu }
  })

  function fmtUtil(v) {
    return v == null || v < 0 ? '—' : v + '%'
  }

  function handleGetBalance() {
    log('page mining:', 'refreshing balance.')
    refreshingBalance = true
    getBalance($form.symbol, $form.address)
      .then((data) => (balance = data))
      .finally(() => {
        refreshingBalance = false
      })
  }

  function openStats() {
    ipc.send(
      'emitOpenURL',
      `https://unmineable.com/coins/${$form.symbol}/address/${$form.address}`,
    )
  }

  async function handleBackToSelectCoin() {
    log('page mining:', 'back to select coin')
    if ($isMining) {
      ipc.listen('onMiningStopped', () => {
        router.pop()
      })
      ipc.send('emitStopMining')
    } else {
      router.pop()
    }
  }

  function enabledMiners() {
    const miners = []
    if ($form.cpuEnabled) miners.push('xmrig')
    if ($form.gpuEnabled) miners.push('thinminerpro')
    return miners
  }

  function handleStart() {
    log('page mining:', 'start')
    const miners = enabledMiners()
    if (miners.length === 0) return

    resetHashrate()
    $cpuHashrate = 0
    $gpuHashrate = 0

    ipc.listen('onMiningStarted', () => {
      $isMining = true
    })
    ipc.send('emitStartMining', JSON.stringify({ ...$form, miners }))
  }

  function handleStop() {
    log('page mining:', 'stop')
    ipc.listen('onMiningStopped', () => {
      $isMining = false
    })
    ipc.send('emitStopMining')
  }

  tryOnMount(() => {
    handleGetBalance()
    startUtilPolling()
  })
  tryOnDestroy(() => {
    $miningLogs.length = 0
    stopUtilPolling()
  })
</script>

<section class="flex flex-col h-full overflow-y-auto">
  <div class="flex justify-between items-center">
    <div
      class="text-blue-400 text-sm flex cursor-pointer"
      on:click={handleBackToSelectCoin}
    >
      ← Back to set coin & address
    </div>
    <TopButtons />
  </div>

  <!-- Address -->
  <div class="mt-5">
    <h5 class="mb-1">Address</h5>
    <div class="flex items-center justify-between">
      <sl-tooltip placement="top" hoist content={$form.address}>
        <p
          class="text-gray-500 text-xs m-0 break-all overflow-ellipsis whitespace-nowrap overflow-hidden mr-8"
        >
          {$form.address}
        </p>
      </sl-tooltip>
      <sl-button size="small" on:click={openStats}>Stats</sl-button>
    </div>
  </div>

  <!-- Balance -->
  <div class="mt-5">
    <div class="flex items-center">
      <h5>Balance</h5>
      <IconRefresh
        class={`w-3 ml-2 cursor-pointer ${
          refreshingBalance ? 'animate-spin' : ''
        }`}
        on:click={handleGetBalance}
      />
    </div>
    <div class="flex items-end my-2">
      <p class="text-3xl m-0 mr-2 font-semibold">
        {balance.pendingBalance || 0}
      </p>
      <span>{$form.symbol || ''}</span>
    </div>
    <div class="flex flex-col">
      <p class="m-0 text-sm">
        <span class="text-gray-500">Last 24h Reward:</span>
        <span class="font-semibold">{balance.total24h || 0}</span>
      </p>
      <p class="m-0 text-sm">
        <span class="text-gray-500">Total Paid:</span>
        <span class="font-semibold">{balance.totalPaid || 0}</span>
      </p>
    </div>
  </div>

  <!-- Miners -->
  <div class="mt-5">
    <div class="text-gray-500 mb-1">Miners</div>
    <label
      class="flex items-center text-sm cursor-pointer select-none mb-1"
    >
      <input
        type="checkbox"
        class="mr-2"
        bind:checked={$form.cpuEnabled}
        disabled={$isMining}
      />
      CPU — XMRig<span class="text-gray-400 ml-1">· RandomX</span>
    </label>
    <label class="flex items-center text-sm cursor-pointer select-none">
      <input
        type="checkbox"
        class="mr-2"
        bind:checked={$form.gpuEnabled}
        disabled={$isMining}
      />
      GPU — Thinminerpro<span class="text-gray-400 ml-1">· KawPow</span>
    </label>
  </div>

  <!-- Hashrate + Start/Stop -->
  <div class="mt-5 flex justify-between items-end">
    <div>
      <div class="text-gray-500 text-sm mb-1">Hashrate</div>
      <div class="text-sm leading-relaxed">
        <div>
          CPU:
          <span class="font-semibold">
            {$form.cpuEnabled ? formatHashrate($cpuHashrate) : '—'}
          </span>
        </div>
        <div>
          GPU:
          <span class="font-semibold">
            {$form.gpuEnabled ? formatHashrate($gpuHashrate) : '—'}
          </span>
        </div>
      </div>
    </div>
    {#if !$isMining}
      <sl-button
        type="primary"
        disabled={$preparing || (!$form.cpuEnabled && !$form.gpuEnabled)}
        on:click={handleStart}>Start</sl-button
      >
    {:else}
      <sl-button type="danger" disabled={$preparing} on:click={handleStop}
        >Stop</sl-button
      >
    {/if}
  </div>

  <!-- Hashrate trend -->
  <div class="mt-3">
    <HashratesChart />
  </div>

  <!-- System load -->
  <div
    class="mt-3 flex items-center justify-between text-xs text-gray-500"
  >
    <div>
      System load — CPU:
      <span class="font-semibold">{fmtUtil($utilization.cpu)}</span>
      · GPU:
      <span class="font-semibold">{fmtUtil($utilization.gpu)}</span>
    </div>
    <label class="flex items-center cursor-pointer select-none">
      <span class="mr-1">refresh</span>
      <select
        bind:value={utilInterval}
        class="rounded border border-gray-300 bg-white text-xs dark:border-gray-600 dark:bg-gray-800 dark:text-gray-50"
      >
        <option value={5}>5s</option>
        <option value={10}>10s</option>
        <option value={30}>30s</option>
        <option value={60}>60s</option>
      </select>
    </label>
  </div>

  <!-- Donate + live-log toggle -->
  <div class="mt-4 flex items-center justify-between">
    <Donate />
    <label
      class="flex items-center text-xs text-gray-500 cursor-pointer select-none"
    >
      <input type="checkbox" class="mr-2" bind:checked={showLiveLog} />
      Show live log
    </label>
  </div>

  {#if showLiveLog}
    <pre
      bind:this={liveLogEl}
      class="mt-2 h-48 overflow-auto select-text bg-gray-50 dark:bg-gray-900 text-xs rounded-md p-2 m-0">{liveLogText}</pre>
  {/if}
</section>
