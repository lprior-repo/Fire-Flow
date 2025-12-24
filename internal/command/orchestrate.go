package command

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// SyncBeadsCommand syncs beads database from source to working directory
type SyncBeadsCommand struct {
	SourceDir  string
	WorkingDir string
}

// Execute syncs beads JSONL files and reinitializes the database
func (cmd *SyncBeadsCommand) Execute() error {
	if cmd.SourceDir == "" {
		cmd.SourceDir = "/home/lewis/src/Fire-Flow"
	}
	if cmd.WorkingDir == "" {
		cwd, _ := os.Getwd()
		cmd.WorkingDir = cwd
	}

	sourceBeads := filepath.Join(cmd.SourceDir, ".beads")
	workingBeads := filepath.Join(cmd.WorkingDir, ".beads")

	// Ensure working beads directory exists
	if err := os.MkdirAll(workingBeads, 0755); err != nil {
		return fmt.Errorf("failed to create beads directory: %w", err)
	}

	// Copy JSONL files from source
	files, err := filepath.Glob(filepath.Join(sourceBeads, "*.jsonl"))
	if err != nil {
		return fmt.Errorf("failed to glob JSONL files: %w", err)
	}

	for _, src := range files {
		dst := filepath.Join(workingBeads, filepath.Base(src))
		if err := copyFile(src, dst); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to copy %s: %v\n", src, err)
		}
	}

	// Remove stale database to force reimport
	dbPath := filepath.Join(workingBeads, "beads.db")
	os.Remove(dbPath)

	// Initialize and import
	initCmd := exec.Command("bd", "init", "--prefix", "Fire-Flow")
	initCmd.Dir = cmd.WorkingDir
	initCmd.Run() // Ignore errors - might already be initialized

	jsonlPath := filepath.Join(workingBeads, "completion-summary.jsonl")
	if _, err := os.Stat(jsonlPath); err == nil {
		importCmd := exec.Command("bd", "import", jsonlPath)
		importCmd.Dir = cmd.WorkingDir
		importCmd.Run()
	}

	// Count ready beads
	readyCmd := exec.Command("bd", "ready")
	readyCmd.Dir = cmd.WorkingDir
	output, _ := readyCmd.Output()
	count := strings.Count(string(output), "Fire-Flow-")

	fmt.Printf(`{"synced": true, "ready_count": %d}`, count)
	fmt.Println()
	return nil
}

// NextBeadCommand gets the next ready bead ID
type NextBeadCommand struct {
	WorkingDir string
}

// Execute returns the next ready bead ID as JSON
func (cmd *NextBeadCommand) Execute() error {
	if cmd.WorkingDir == "" {
		cwd, _ := os.Getwd()
		cmd.WorkingDir = cwd
	}

	readyCmd := exec.Command("bd", "ready")
	readyCmd.Dir = cmd.WorkingDir
	output, err := readyCmd.Output()
	if err != nil {
		fmt.Println(`{"bead_id": "", "error": "failed to get ready beads"}`)
		return nil
	}

	// Extract first bead ID
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.Contains(line, "Fire-Flow-") {
			// Extract the bead ID
			parts := strings.Fields(line)
			for _, part := range parts {
				if strings.HasPrefix(part, "Fire-Flow-") {
					// Clean up the ID (remove trailing colon or punctuation)
					beadID := strings.TrimSuffix(part, ":")
					beadID = strings.TrimSuffix(beadID, ",")
					fmt.Printf(`{"bead_id": "%s"}`, beadID)
					fmt.Println()
					return nil
				}
			}
		}
	}

	fmt.Println(`{"bead_id": ""}`)
	return nil
}

// RunAICommand runs OpenCode on a specific bead
type RunAICommand struct {
	BeadID     string
	WorkingDir string
	Model      string
}

// Execute runs OpenCode with the specified model on a bead
func (cmd *RunAICommand) Execute() error {
	if cmd.BeadID == "" {
		return fmt.Errorf("bead_id is required")
	}
	if cmd.WorkingDir == "" {
		cwd, _ := os.Getwd()
		cmd.WorkingDir = cwd
	}
	if cmd.Model == "" {
		cmd.Model = "local/qwen3-coder"
	}

	// Mark bead as in progress
	updateCmd := exec.Command("bd", "update", cmd.BeadID, "--status=in_progress")
	updateCmd.Dir = cmd.WorkingDir
	updateCmd.Run()

	// Get bead details
	showCmd := exec.Command("bd", "show", cmd.BeadID)
	showCmd.Dir = cmd.WorkingDir
	beadDetails, _ := showCmd.Output()

	// Build prompt
	prompt := fmt.Sprintf(`Work on this bead and complete it: %s

Details:
%s

Instructions:
1. Analyze what needs to be done
2. Implement the changes
3. Run tests to verify
4. When complete, close the bead with: bd close %s`, cmd.BeadID, string(beadDetails), cmd.BeadID)

	// Set up environment for OpenCode
	env := os.Environ()
	env = append(env,
		"XDG_DATA_HOME=/home/lewis/.kestra/opencode-data",
		"XDG_STATE_HOME=/home/lewis/.kestra/opencode-state",
		"XDG_CONFIG_HOME=/home/lewis/.config",
	)

	// Ensure writable directories exist
	os.MkdirAll("/home/lewis/.kestra/opencode-data", 0755)
	os.MkdirAll("/home/lewis/.kestra/opencode-state", 0755)

	// Run OpenCode
	opencodeCmd := exec.Command("opencode", "run", "-m", cmd.Model, prompt)
	opencodeCmd.Dir = cmd.WorkingDir
	opencodeCmd.Env = env
	opencodeCmd.Stdout = os.Stdout
	opencodeCmd.Stderr = os.Stderr

	err := opencodeCmd.Run()

	// Sync beads after completion
	syncCmd := exec.Command("bd", "sync")
	syncCmd.Dir = cmd.WorkingDir
	syncCmd.Run()

	result := map[string]interface{}{
		"bead_id":   cmd.BeadID,
		"completed": err == nil,
	}
	if err != nil {
		result["error"] = err.Error()
	}

	jsonOut, _ := json.Marshal(result)
	fmt.Println(string(jsonOut))
	return nil
}

// PushChangesCommand pushes changes back to source repository
type PushChangesCommand struct {
	WorkingDir string
	Message    string
}

// Execute commits and pushes changes
func (cmd *PushChangesCommand) Execute() error {
	if cmd.WorkingDir == "" {
		cwd, _ := os.Getwd()
		cmd.WorkingDir = cwd
	}
	if cmd.Message == "" {
		cmd.Message = "OpenCode+Qwen3: Auto-commit from Fire-Flow"
	}

	// Git add
	addCmd := exec.Command("git", "add", "-A")
	addCmd.Dir = cmd.WorkingDir
	addCmd.Run()

	// Check if there are changes to commit
	diffCmd := exec.Command("git", "diff", "--cached", "--quiet")
	diffCmd.Dir = cmd.WorkingDir
	hasChanges := diffCmd.Run() != nil

	committed := false
	pushed := false

	if hasChanges {
		// Git commit
		commitCmd := exec.Command("git", "commit", "-m", cmd.Message)
		commitCmd.Dir = cmd.WorkingDir
		if err := commitCmd.Run(); err == nil {
			committed = true
		}

		// Git push
		pushCmd := exec.Command("git", "push", "origin", "main")
		pushCmd.Dir = cmd.WorkingDir
		if err := pushCmd.Run(); err == nil {
			pushed = true
		}
	}

	// Sync beads
	syncCmd := exec.Command("bd", "sync")
	syncCmd.Dir = cmd.WorkingDir
	syncCmd.Run()

	result := map[string]interface{}{
		"committed": committed,
		"pushed":    pushed,
	}

	jsonOut, _ := json.Marshal(result)
	fmt.Println(string(jsonOut))
	return nil
}

// copyFile copies a file from src to dst
func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0644)
}
