<script>
  import { form } from '../store'

  // Disable switching while a miner is running.
  export let disabled = false

  const miners = [
    { id: 'xmrig', label: 'CPU', sub: 'XMRig · RandomX' },
    { id: 'thinminerpro', label: 'GPU', sub: 'Thinminerpro · KawPow' },
  ]

  function select(id) {
    if (disabled) return
    $form = { ...$form, miner: id }
  }
</script>

<div class="flex w-full rounded-md overflow-hidden border border-gray-200 dark:border-gray-700">
  {#each miners as m}
    <button
      type="button"
      {disabled}
      class="flex-1 px-3 py-2 text-center focus:outline-none"
      class:bg-indigo-500={$form.miner === m.id}
      class:text-white={$form.miner === m.id}
      class:text-gray-500={$form.miner !== m.id}
      class:cursor-pointer={!disabled}
      class:cursor-not-allowed={disabled}
      class:opacity-50={disabled && $form.miner !== m.id}
      on:click={() => select(m.id)}
    >
      <div class="text-sm font-semibold">{m.label}</div>
      <div class="text-xs opacity-80">{m.sub}</div>
    </button>
  {/each}
</div>
