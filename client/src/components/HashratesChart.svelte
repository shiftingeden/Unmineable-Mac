<script>
  import { tryOnMount } from '@svelte-use/core'
  import c3 from 'c3'
  import 'c3/c3.css'
  import { cpuHashrate, gpuHashrate } from '../store'

  let el
  let chart

  // Rolling history for each miner. CPU and GPU hash-rates differ by orders
  // of magnitude, so each series gets its own y-axis (y / y2).
  let cpuHist = [0, 0]
  let gpuHist = [0, 0]

  $: pushPoint($cpuHashrate, $gpuHashrate)

  function pushPoint(cpu, gpu) {
    cpuHist = [...cpuHist, cpu || 0].slice(-24)
    gpuHist = [...gpuHist, gpu || 0].slice(-24)
    if (chart) {
      chart.load({
        columns: [
          ['CPU', ...cpuHist],
          ['GPU', ...gpuHist],
        ],
      })
    }
  }

  tryOnMount(() => {
    chart = c3.generate({
      bindto: el,
      data: {
        columns: [
          ['CPU', ...cpuHist],
          ['GPU', ...gpuHist],
        ],
        type: 'area-spline',
        axes: { CPU: 'y', GPU: 'y2' },
        colors: { CPU: '#0070F3', GPU: '#7c3aed' },
      },
      transition: { duration: null },
      point: { show: false },
      axis: {
        x: { show: false },
        y: { show: false },
        y2: { show: false },
      },
      legend: { show: true },
    })
  })
</script>

<div bind:this={el} class="h-32 hashrates-chart" />

<style global>
  .hashrates-chart .c3-tooltip-container table.c3-tooltip tbody tr:first-child {
    display: none;
  }
  .dark .hashrates-chart .c3-tooltip-container table.c3-tooltip tr {
    color: #333;
  }
</style>
