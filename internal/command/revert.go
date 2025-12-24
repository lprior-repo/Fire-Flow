package command

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/lprior-repo/Fire-Flow/internal/utils"
)

// RevertCommand represents the revert command
// This command reverts the last commit and updates state.json
type RevertCommand struct{}

// Execute runs the revert command to undo the last commit and update state
// It executes: git revert HEAD and updates the state file
func (cmd *RevertCommand) Execute() error {
	// Execute git revert HEAD
	fmt.Println("Running: git revert HEAD")
	revertCmd := exec.Command("git", "revert", "HEAD")
	revertOutput, err := revertCmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to execute 'git revert HEAD': %w\nOutput: %s", err, strings.TrimSpace(string(revertOutput)))
	}
	fmt.Println("git revert completed successfully")

	// Load state and update it
	state, err := utils.LoadStateWithValidation()
	if err != nil {
		return fmt.Errorf("failed to load state: %w", err)
	}

	// Reset the revert streak
	state.ResetRevertStreak()

	// Update the last commit time (revert also updates commit timestamp)
	state.LastCommitTime = time.Now()

	// Save updated state
	statePath := utils.GetStatePath()
	if err := state.SaveToFile(statePath); err != nil {
		return fmt.Errorf("failed to save state: %w", err)
	}

	fmt.Println("State updated successfully")
	fmt.Println("Reverted last commit")

	return nil
}