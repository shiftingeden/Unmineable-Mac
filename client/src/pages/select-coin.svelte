<script>
  import { tryOnMount } from '@svelte-use/core'
  import { listen } from 'svelte/internal'
  import * as router from 'svelte-spa-router'
  import '@shoelace-style/shoelace/dist/components/form/form'
  import '@shoelace-style/shoelace/dist/components/input/input'
  import '@shoelace-style/shoelace/dist/components/button/button'
  import 'vercel-toast/dist/vercel-toast.css'
  import { createToast } from 'vercel-toast'

  import { ipc } from '../ipc'
  import {
    unMineableCoins,
    getReferralCode,
    validateAddress,
  } from '../server/unMineable'
  import { form, preparing } from '../store'
  import { parseFormData } from '../util/form'
  import { getStorage, setStorage } from '../util/storage'
  import TopButtons from '../components/TopButtons.svelte'
  import { log } from '../util/log'

  let formEl
  let inputAddressEl
  let inputReferralCodeEl

  const savedForm = getStorage('form') || {}

  // Coin selection uses a native <select>. Shoelace's <sl-select> did not
  // render its options reliably in this build, so we use the platform
  // control, which always works.
  let selectedSymbol = savedForm.symbol || ''

  function onStart(event) {
    log('page select-coin:', 'start')
    $preparing = true

    const data = parseFormData(event.detail.formData)
    data.symbol = selectedSymbol

    if (!data.symbol) {
      $preparing = false
      createToast('Please select a coin or token first.', {
        type: 'error',
        cancel: 'Cancel',
      })
      return
    }

    log('page select-coin:', 'validating address')
    validateAddress(data.symbol, data.address)
      .then((isExist) => {
        if (isExist) {
          $form = { ...$form, ...data }

          setStorage('form', $form)
          setStorage($form.symbol, $form.address)

          $preparing = false
          router.push('/mining')
        } else {
          createToast(
            `Your address doesn't exist on unMineable, please register it first.`,
            {
              type: 'error',
              action: {
                text: 'Register',
                callback: (toast) => {
                  ipc.send(
                    'emitOpenURL',
                    `https://unmineable.com/coins/${data.symbol}/address`,
                  )

                  toast.destory()
                },
              },
              cancel: 'Cancel',
            },
          )
        }
      })
      .catch((error) => {
        createToast(String(error), {
          type: 'error',
          cancel: 'Cancel',
        })
      })
      .finally(() => {
        $preparing = false
      })
  }

  function onSelectCoinChange() {
    if (inputAddressEl) {
      inputAddressEl.value = getStorage(selectedSymbol) || ''
    }
    if (inputReferralCodeEl) {
      inputReferralCodeEl.value = getReferralCode(unMineableCoins, selectedSymbol)
    }
  }

  tryOnMount(() => {
    listen(formEl, 'sl-submit', onStart)

    if (inputAddressEl) inputAddressEl.value = savedForm.address || ''
    if (inputReferralCodeEl) {
      inputReferralCodeEl.value = savedForm.referralCode || ''
    }
  })
</script>

<div class="flex justify-end">
  <TopButtons />
</div>

<sl-form bind:this={formEl}>
  <div class="my-4">
    <label class="block text-sm mb-1" for="coin-select">
      Select a coin or token
    </label>
    <select
      id="coin-select"
      name="symbol"
      bind:value={selectedSymbol}
      on:change={onSelectCoinChange}
      class="w-full p-2 rounded-md border border-gray-300 bg-white text-sm dark:border-gray-600 dark:bg-gray-800 dark:text-gray-50"
    >
      <option value="" disabled>— choose a coin —</option>
      {#each unMineableCoins as coin (coin[1])}
        <option value={coin[1]}>{coin[0]} ({coin[1]})</option>
      {/each}
    </select>
  </div>

  <sl-input
    name="address"
    class="my-4"
    label="Enter your address"
    required
    bind:this={inputAddressEl}
  />

  <sl-input
    name="referralCode"
    class="my-4"
    label="Referral Code(Optional)"
    bind:this={inputReferralCodeEl}
  >
    <p slot="help-text" class="mt-2 text-xs text-gray-400">
      You can lower your fees to 0.75% with this valid referral code! Or you use
      your own one.
    </p>
  </sl-input>

  <sl-button
    type="primary"
    class="w-full mt-4"
    submit
    loading={$preparing}
    disabled={$preparing}>Continue</sl-button
  >
</sl-form>
