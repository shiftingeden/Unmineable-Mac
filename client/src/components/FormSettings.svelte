<script>
  import { tryOnMount } from '@svelte-use/core'
  import { listen } from 'svelte/internal'
  import '@shoelace-style/shoelace/dist/components/form/form'
  import '@shoelace-style/shoelace/dist/components/range/range'
  import '@shoelace-style/shoelace/dist/components/input/input'

  import { form, cpuCores } from '../store'
  import * as formUtils from '../util/form'
  import { useDispatch } from '../use/dispatch'
  import Link from './Link.svelte'

  const { dispatch } = useDispatch()

  $: step = 100 / $cpuCores

  let tweakForm = {
    cpuUsage: $form.cpuUsage,
    cpuMinerName: $form.cpuMinerName,
    gpuMinerName: $form.gpuMinerName,
  }

  let formEl

  export function getFormData() {
    return formEl.getFormData()
  }
  export function setFormData(data) {
    formUtils.setFormData(formEl, data)
    tweakForm = { ...tweakForm, ...data }
  }

  tryOnMount(() => {
    formEl.childNodes.forEach((el) => {
      if (el.name) {
        listen(el, 'sl-change', (event) => {
          dispatch('change', { ...$form, [el.name]: event.target.value })
          tweakForm[el.name] = event.target.value
        })
      }
    })
  })
</script>

<sl-form bind:this={formEl} class="p-2">
  <sl-input
    name="cpuMinerName"
    class="mb-4"
    label="CPU miner name"
    value={tweakForm.cpuMinerName}
  />

  <sl-input
    name="gpuMinerName"
    class="mb-4"
    label="GPU miner name"
    value={tweakForm.gpuMinerName}
  >
    <p slot="help-text" class="mt-2 text-xs text-gray-400">
      Worker names shown on your unMineable dashboard — each miner can have
      its own. See
      <Link
        url="https://unmineable.com/support/article/how-to-setup-xmrig-for-cpu-mining"
        class="underline hover:text-indigo-500">unMineable's XMRig guide</Link
      >.
    </p>
  </sl-input>

  <sl-range
    name="cpuUsage"
    label={`CPU Usage (${tweakForm.cpuUsage}%)`}
    min={step}
    max="100"
    {step}
    value={tweakForm.cpuUsage}
  />
  {#if !$form.cpuEnabled}
    <p class="m-0 mt-2 text-xs text-gray-400">
      CPU Usage only affects the CPU miner (XMRig), which is currently off.
    </p>
  {/if}
</sl-form>
