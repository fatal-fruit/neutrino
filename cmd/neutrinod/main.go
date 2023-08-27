package main

import (
	"fmt"
	"github.com/fatal-fruit/neutrino/app"
	"os"

	svrcmd "github.com/cosmos/cosmos-sdk/server/cmd"
	"github.com/fatal-fruit/neutrino/cmd/neutrinod/cmd"
)

func main() {

	rootCmd, _ := cmd.NewRootCmd()

	if err := svrcmd.Execute(rootCmd, "", app.DefaultNodeHome); err != nil {
		fmt.Fprintln(rootCmd.OutOrStderr(), err)
		os.Exit(1)
	}
}
