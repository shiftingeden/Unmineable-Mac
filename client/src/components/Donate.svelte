<script>
  import 'vercel-toast/dist/vercel-toast.css'
  import { createToast } from 'vercel-toast'

  // Litecoin donation address.
  const LTC_ADDRESS = 'ltc1qqc63qsqnprhmsw6skn9zd0sxzrgv0rfgvlq84u'

  let revealed = false

  async function donate() {
    revealed = true
    try {
      await navigator.clipboard.writeText(LTC_ADDRESS)
      createToast('LTC address copied to clipboard', {
        type: 'success',
        timeout: 3000,
      })
    } catch (e) {
      createToast('Select the LTC address below to copy it', {
        timeout: 3000,
      })
    }
  }
</script>

<div class="flex flex-col">
  <button
    type="button"
    class="text-xs text-gray-500 m-0 p-0 underline hover:text-indigo-500 cursor-pointer bg-transparent border-0 text-left"
    on:click={donate}
  >
    Donate (LTC) 💜
  </button>
  {#if revealed}
    <code class="mt-1 text-xs text-gray-400 break-all select-text">
      {LTC_ADDRESS}
    </code>
  {/if}
</div>
