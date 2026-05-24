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
	// Running miner processes, keyed by miner id ("xmrig" | "thinminerpro").
	// More than one may run at a time (CPU + GPU together).
	miningProcesses := map[string]*exec.Cmd{}

	stopAll := func() {
		for id, p := range miningProcesses {
			if p != nil && p.Process != nil {
				p.Process.Kill()
			}
			delete(miningProcesses, id)
		}
	}

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
		Miners       []string `json:"miners"`
		MinerName    string   `json:"minerName"`
		Symbol       string   `json:"symbol"`
		Address      string   `json:"address"`
		ReferralCode string   `json:"referralCode"`
		CPUUsage     int      `json:"cpuUsage"`
	}

	w.Bind("emitStartMining", func(data string) {
		var form Form
		json.Unmarshal([]byte(data), &form)

		fmt.Printf("form: %v\n", form)

		if len(form.Miners) == 0 {
			w.Eval(`onMiningStartedError("No miner is enabled")`)
			return
		}

		started := false
		for _, id := range form.Miners {
			if _, running := miningProcesses[id]; running {
				started = true
				continue
			}

			cmdStr, workDir, err := BuildMinerCommand(MinerForm{
				Miner:        id,
				MinerName:    form.MinerName,
				Symbol:       form.Symbol,
				Address:      form.Address,
				ReferralCode: form.ReferralCode,
				CPUUsage:     form.CPUUsage,
			})
			if err != nil {
				w.Eval(fmt.Sprintf(`onMiningStartedError("%s")`, JSEscape(err.Error())))
				continue
			}

			process, err := RunCommand(cmdStr, workDir)
			if err != nil {
				w.Eval(fmt.Sprintf(`onMiningStartedError("%s")`, JSEscape(err.Error())))
				continue
			}

			miningProcesses[id] = process
			started = true
		}

		if started {
			w.Eval("onMiningStarted()")
		}
	})

	w.Bind("emitStopMining", func() {
		stopAll()
		w.Eval("onMiningStopped()")
	})

	// emitGetUtilization samples CPU/GPU load on demand; the UI polls it on
	// an interval. The samplers are quick (see utilization.go).
	w.Bind("emitGetUtilization", func() {
		cpu, gpu := SampleUtilization()
		w.Eval(fmt.Sprintf("onUtilization(%d, %d)", cpu, gpu))
	})

	w.Bind("emitOpenURL", func(url string) {
		browser.OpenURL(url)
	})
}
