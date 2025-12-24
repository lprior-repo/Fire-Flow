package command

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/lprior-repo/Fire-Flow/internal/utils"
)

// RevertCommand represents the revert command
// This command reverts the last commit by resetting to the previous commit and updates state.json
type RevertCommand struct{}

// Execute runs the revert command to undo the last commit and update state
// It executes: git reset --hard HEAD and updates the state file
func (cmd *RevertCommand) Execute() error {
	// Execute git reset --hard HEAD
	fmt.Println("Running: git reset --hard HEAD")
	resetCmd := exec.Command("git", "reset", "--hard", "HEAD")
	resetOutput, err := resetCmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to execute 'git reset --hard HEAD': %w\nOutput: %s", err, strings.TrimSpace(string(resetOutput)))
	}
	fmt.Println("git reset --hard HEAD completed successfully")

	// Load state and update it
	state, err := utils.LoadStateWithValidation()
	if err != nil {
		return fmt.Errorf("failed to load state: %w", err)
	}

	// Record test result as failed (revert implies tests failed)
	state.SetTestResult(false)

	// Clear overlay state if active
	if state.IsOverlayActive() {
		state.SetOverlayUnmounted()
	}

	// Save updated state
	statePath := utils.GetStatePath()
	if err := state.SaveToFile(statePath); err != nil {
		return fmt.Errorf("failed to save state: %w", err)
	}

	fmt.Println("State updated successfully")
	fmt.Println("Reverted last commit")

	return nil
}
