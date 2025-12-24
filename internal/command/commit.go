package command

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/lprior-repo/Fire-Flow/internal/utils"
)

// CommitCommand represents the commit command
// This command executes git add ., git commit -m <message>, and updates state.json
type CommitCommand struct {
	Message string
}

// Execute runs the commit command to stage changes, commit them, and update state
// It executes: git add ., git commit -m <message>, and updates the state file
func (cmd *CommitCommand) Execute() error {
	// Execute git add .
	fmt.Println("Running: git add .")
	addCmd := exec.Command("git", "add", ".")
	addOutput, err := addCmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to execute 'git add .': %w\nOutput: %s", err, strings.TrimSpace(string(addOutput)))
	}
	fmt.Println("git add . completed successfully")

	// Execute git commit -m <message>
	fmt.Printf("Running: git commit -m \"%s\"\n", cmd.Message)
	commitCmd := exec.Command("git", "commit", "-m", cmd.Message)
	commitOutput, err := commitCmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to execute 'git commit -m \"%s\"': %w\nOutput: %s", cmd.Message, err, strings.TrimSpace(string(commitOutput)))
	}
	fmt.Println("git commit completed successfully")

	// Load state and update it
	state, err := utils.LoadStateWithValidation()
	if err != nil {
		return fmt.Errorf("failed to load state: %w", err)
	}

	// Update the last commit time
	state.LastCommitTime = time.Now()

	// Save updated state
	statePath := utils.GetStatePath()
	if err := state.SaveToFile(statePath); err != nil {
		return fmt.Errorf("failed to save state: %w", err)
	}

	fmt.Println("State updated successfully")
	fmt.Printf("Committed with message: \"%s\"\n", cmd.Message)

	return nil
}