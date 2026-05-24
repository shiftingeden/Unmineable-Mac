package lib

import (
	"fmt"
	"os"
	"strings"

	. "github.com/klauspost/cpuid/v2"
)

func IsIntel() bool {
	fmt.Printf("CPU.BrandName: %v\n", CPU.BrandName)
	return strings.Contains(CPU.BrandName, "Intel")
}

func Ternay(cond bool, res1 interface{}, res2 interface{}) interface{} {
	if cond {
		return res1
	} else {
		return res2
	}
}

// JSEscape escapes a string so it can be safely embedded inside a
// double-quoted JavaScript string literal passed to webview.Eval.
func JSEscape(s string) string {
	r := strings.NewReplacer(
		`\`, `\\`,
		`"`, `\"`,
		"\n", `\n`,
		"\r", `\r`,
		"\t", `\t`,
	)
	return r.Replace(s)
}

// https://tehub.com/a/44BceBfRK0
func isRunBuild() bool {
	tempDir := os.TempDir()
	execDir, err := os.Executable()
	if err != nil {
		fmt.Println(err)
	}

	return !strings.Contains(execDir, tempDir)
}
