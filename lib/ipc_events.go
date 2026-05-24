package lib

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"runtime"

	"github.com/2nthony/webview"
	"github.com/pkg/browser"
)

// client events
func RegisterIPCEvents(w webview.WebView) {
	var miningProcess *exec.Cmd

	w.Bind("emitPageReady", func() {
		fmt.Println("emitPageReady")
		w.Eval(fmt.Sprintf(`
        onPageReady({
          cpuCores: %s
        })
        `,
			fmt.Sprint(runtime.NumCPU()),
		))
	})

	type Form struct {
		Miner        string `json:"miner"`
		Symbol       string `json:"symbol"`
		Address      string `json:"address"`
		ReferralCode string `json:"referralCode"`
		CPUUsage     int    `json:"cpuUsage"`
	}

	w.Bind("emitStartMining", func(data string) {
		var form Form
		json.Unmarshal([]byte(data), &form)

		fmt.Printf("form: %v\n", form)

		if miningProcess != nil {
			w.Eval("onMiningStarted()")
			return
		}

		cmdStr, err := BuildMinerCommand(MinerForm{
			Miner:        form.Miner,
			Symbol:       form.Symbol,
			Address:      form.Address,
			ReferralCode: form.ReferralCode,
			CPUUsage:     form.CPUUsage,
		})
		if err != nil {
			w.Eval(fmt.Sprintf(`onMiningStartedError("%s")`, JSEscape(err.Error())))
			return
		}

		process, err := RunCommand(cmdStr)
		if err != nil {
			w.Eval(fmt.Sprintf(`onMiningStartedError("%s")`, JSEscape(err.Error())))
			return
		}

		w.Eval("onMiningStarted()")

		miningProcess = process
	})

	w.Bind("emitStopMining", func() {
		if miningProcess != nil {
			// prefer kill the process
			miningProcess.Process.Kill()
			miningProcess = nil
			w.Eval("onMiningStopped()")
		}
	})

	w.Bind("emitOpenURL", func(url string) {
		browser.OpenURL(url)
	})
}
