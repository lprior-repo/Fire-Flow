package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/lprior-repo/Fire-Flow/internal/config"
	"github.com/lprior-repo/Fire-Flow/internal/state"
	"github.com/lprior-repo/Fire-Flow/internal/version"
)

func main() {
	log.Printf("%s starting...", version.Info())
	fmt.Printf("Welcome to %s!\n", version.Name)
	log.Println("Fire-Flow is ready to orchestrate workflows")

	// Handle command parsing
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	command := os.Args[1]

	switch command {
	case "tdd-gate":
		handleTDDGateCommand()
	case "run-tests":
		handleRunTestsCommand()
	case "commit":
		handleCommitCommand()
	case "revert":
		handleRevertCommand()
	case "init":
		handleInitCommand()
	case "status":
		handleStatusCommand()
	default:
		fmt.Printf("Unknown command: %s\n", command)
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("Usage: fire-flow <command> [args]")
	fmt.Println("Available commands:")
	fmt.Println("  init")
	fmt.Println("  status")
	fmt.Println("  tdd-gate --file <path>")
	fmt.Println("  run-tests [--json]")
	fmt.Println("  commit --message \"commit message\"")
	fmt.Println("  revert")
}

func handleTDDGateCommand() {
	if len(os.Args) < 4 || os.Args[2] != "--file" {
		fmt.Println("Usage: fire-flow tdd-gate --file <path>")
		os.Exit(1)
	}

	filePath := os.Args[3]
	
	// Create and execute TDD Gate command
	cmd := &TDDGateCommand{filePath: filePath}
	if err := cmd.Execute(); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}

func handleRunTestsCommand() {
	jsonOutput := false
	for _, arg := range os.Args {
		if arg == "--json" {
			jsonOutput = true
			break
		}
	}
	
	// Create and execute Run Tests command
	cmd := &RunTestsCommand{jsonOutput: jsonOutput}
	if err := cmd.Execute(); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}

func handleCommitCommand() {
	message := ""
	for i, arg := range os.Args {
		if arg == "--message" && i+1 < len(os.Args) {
			message = os.Args[i+1]
			break
		}
	}
	
	// Create and execute Commit command
	cmd := &GitOpsCommand{command: "commit", message: message}
	if err := cmd.Execute(); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}

func handleRevertCommand() {
	// Create and execute Revert command
	cmd := &GitOpsCommand{command: "revert", message: ""}
	if err := cmd.Execute(); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}

func handleStatusCommand() {
	// Create and execute Status command
	cmd := &StatusCommand{}
	if err := cmd.Execute(); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}

func handleInitCommand() {
	// Create and execute Init command
	cmd := &InitCommand{}
	if err := cmd.Execute(); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}

// TDDGateCommand represents the tdd-gate command
type TDDGateCommand struct {
	filePath string
}

// Execute runs the TDD gate logic
func (cmd *TDDGateCommand) Execute() error {
	// Load configuration
	cfg, err := loadConfig()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Load state
	state, err := loadState()
	if err != nil {
		return fmt.Errorf("failed to load state: %w", err)
	}

	// Check if file is protected
	if cfg.IsProtected(cmd.filePath) {
		log.Printf("File %s is protected", cmd.filePath)
		return fmt.Errorf("blocked: file %s is protected", cmd.filePath)
	}

	// Check if file is a test file
	if isTestFile(cmd.filePath, cfg.TestPatterns) {
		log.Printf("ALLOWED: Test file %s", cmd.filePath)
		return nil
	}

	// If not a test file, apply TDD gate logic
	if state.IsGreen() {
		log.Printf("BLOCKED: Write test first. State: GREEN")
		return fmt.Errorf("blocked: Write test first. State: GREEN")
	}

	if state.IsRed() {
		log.Printf("ALLOWED: Red state detected")
		return nil
	}

	return nil
}

// isTestFile checks if a file path matches test patterns.
// Patterns can be glob patterns (e.g., "*_test.go") or simple regex-like patterns
// (e.g., "_test\\.go$"). The function first tries glob matching, then falls back
// to simple string matching for common test file conventions.
func isTestFile(filePath string, patterns []string) bool {
	basename := filepath.Base(filePath)
	for _, pattern := range patterns {
		// Try glob pattern matching first
		if matched, err := filepath.Match(pattern, basename); err == nil && matched {
			return true
		}
		// For patterns that look like regex (contain backslashes), try simple substring matching
		// This handles patterns like "_test\\.go$" by checking if file contains "_test.go"
		if strings.Contains(pattern, "\\") {
			if strings.Contains(basename, "_test.go") {
				return true
			}
		}
	}
	return false
}

// RunTestsCommand represents the run-tests command
type RunTestsCommand struct {
	jsonOutput bool
}

// Execute runs the test execution logic
func (cmd *RunTestsCommand) Execute() error {
	// Load configuration
	cfg, err := loadConfig()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Execute tests with timeout
	result, err := runTests(cfg.TestCommand, cfg.Timeout)
	if err != nil {
		return fmt.Errorf("failed to run tests: %w", err)
	}

	// Update state based on test results
	if err := updateState(result); err != nil {
		return fmt.Errorf("failed to update state: %w", err)
	}

	// Output results
	if cmd.jsonOutput {
		output, err := json.MarshalIndent(result, "", "  ")
		if err != nil {
			return fmt.Errorf("failed to marshal result: %w", err)
		}
		fmt.Println(string(output))
	} else {
		fmt.Printf("Test execution completed in %d seconds\n", result.Duration)
		if result.Passed {
			fmt.Println("All tests passed!")
		} else {
			fmt.Printf("Tests failed: %v\n", result.FailedTests)
		}
	}

	return nil
}

// TestResult represents the result of test execution
type TestResult struct {
	Passed     bool     `json:"passed"`
	FailedTests []string `json:"failedTests"`
	Duration   int      `json:"duration"`
	Output     string   `json:"output"`
}

// runTests executes the test command with timeout
func runTests(testCommand string, timeoutSeconds int) (*TestResult, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutSeconds)*time.Second)
	defer cancel()

	// Split command and arguments
	parts := strings.Fields(testCommand)
	if len(parts) == 0 {
		return nil, fmt.Errorf("invalid test command")
	}

	cmd := exec.CommandContext(ctx, parts[0], parts[1:]...)
	
	var outputBuf, errBuf strings.Builder
	cmd.Stdout = &outputBuf
	cmd.Stderr = &errBuf

	start := time.Now()
	err := cmd.Run()
	duration := int(time.Since(start).Seconds())

	result := &TestResult{
		Duration: duration,
		Output:   outputBuf.String(),
	}

	// Parse test output to detect failures
	result.Passed = err == nil
	result.FailedTests = extractFailedTests(outputBuf.String())

	return result, nil
}

// extractFailedTests parses test output to extract failed test names
func extractFailedTests(output string) []string {
	var failedTests []string

	// Parse go test -json output
	lines := strings.Split(output, "\n")
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			continue
		}

		// Parse JSON line for test events
		var event map[string]interface{}
		if err := json.Unmarshal([]byte(line), &event); err != nil {
			// Skip lines that aren't valid JSON
			continue
		}

		// Check if this is a failure event
		action, ok := event["Action"].(string)
		if !ok || action != "fail" {
			continue
		}

		// Extract test name if present
		if testName, ok := event["Test"].(string); ok && testName != "" {
			failedTests = append(failedTests, testName)
		}
	}

	return failedTests
}

// updateState updates the state based on test results
func updateState(result *TestResult) error {
	// Load state
	st, err := loadState()
	if err != nil {
		return err
	}

	// Update failing tests
	st.SetFailingTests(result.FailedTests)

	// Save updated state
	return st.SaveToFile(GetStatePath())
}

// GitOpsCommand represents Git operations commands
type GitOpsCommand struct {
	command string
	message string
}

// Execute runs the Git operation
func (cmd *GitOpsCommand) Execute() error {
	switch cmd.command {
	case "commit":
		return cmd.commit()
	case "revert":
		return cmd.revert()
	default:
		return fmt.Errorf("unknown git operation: %s", cmd.command)
	}
}

// commit executes git add, commit, and updates state
func (cmd *GitOpsCommand) commit() error {
	// Execute git add .
	gitCmd := exec.Command("git", "add", ".")
	if err := gitCmd.Run(); err != nil {
		return fmt.Errorf("failed to git add: %w", err)
	}

	// Execute git commit
	commitMsg := cmd.message
	if commitMsg == "" {
		commitMsg = "WIP"
	}
	
	gitCmd = exec.Command("git", "commit", "-m", commitMsg)
	if err := gitCmd.Run(); err != nil {
		return fmt.Errorf("failed to git commit: %w", err)
	}

	// Get commit hash
	gitCmd = exec.Command("git", "rev-parse", "HEAD")
	output, err := gitCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get commit hash: %w", err)
	}
	
	commitHash := string(output[:len(output)-1]) // Remove newline
	log.Printf("Committed with hash: %s", commitHash)

	// Update state
	if err := updateStateCommit(); err != nil {
		return fmt.Errorf("failed to update state: %w", err)
	}

	return nil
}

// revert executes git reset --hard HEAD and updates state
func (cmd *GitOpsCommand) revert() error {
	// Execute git reset --hard HEAD
	gitCmd := exec.Command("git", "reset", "--hard", "HEAD")
	if err := gitCmd.Run(); err != nil {
		return fmt.Errorf("failed to git reset: %w", err)
	}

	log.Println("Reverted changes")

	// Update state
	if err := updateStateRevert(); err != nil {
		return fmt.Errorf("failed to update state: %w", err)
	}

	return nil
}

// updateStateCommit updates state after a successful commit
func updateStateCommit() error {
	// Load state
	st, err := loadState()
	if err != nil {
		return err
	}

	// Reset revert streak
	st.ResetRevertStreak()

	// Update last commit time
	st.LastCommitTime = time.Now()

	// Save updated state
	return st.SaveToFile(GetStatePath())
}

// updateStateRevert updates state after a revert
func updateStateRevert() error {
	// Load state
	st, err := loadState()
	if err != nil {
		return err
	}

	// Increment revert streak
	st.IncrementRevertStreak()

	// Save updated state
	return st.SaveToFile(GetStatePath())
}

// loadConfig loads configuration from the default location
func loadConfig() (*config.Config, error) {
	return config.LoadFromFile(GetConfigPath())
}

// loadState loads state from the default location
func loadState() (*state.State, error) {
	st, err := state.LoadStateFromFile(GetStatePath())
	if err != nil {
		return nil, err
	}

	// Ensure the failingTests array is properly initialized
	if st.FailingTests == nil {
		st.FailingTests = []string{}
	}

	return st, nil
}

// InitCommand represents the init command
type InitCommand struct{}

// Execute runs the init command to set up TCR environment
func (cmd *InitCommand) Execute() error {
	// Create directories
	tcrPath := GetTCRPath()
	if err := os.MkdirAll(tcrPath, 0755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", tcrPath, err)
	}

	// Create default config file
	configPath := GetConfigPath()
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		// Create default config
		cfg := config.DefaultConfig()
		if err := cfg.SaveToFile(configPath); err != nil {
			return fmt.Errorf("failed to create default config: %w", err)
		}
		log.Printf("Created default config at %s", configPath)
	} else {
		log.Printf("Config file already exists at %s", configPath)
	}

	// Create default state file
	statePath := GetStatePath()
	if _, err := os.Stat(statePath); os.IsNotExist(err) {
		// Create default state
		st := state.NewState()
		if err := st.SaveToFile(statePath); err != nil {
			return fmt.Errorf("failed to create default state: %w", err)
		}
		log.Printf("Created default state at %s", statePath)
	} else {
		log.Printf("State file already exists at %s", statePath)
	}

	fmt.Println("TCR Enforcer initialized successfully!")
	return nil
}

// StatusCommand represents the status command
type StatusCommand struct{}

// Execute runs the status command to show current state
func (cmd *StatusCommand) Execute() error {
	// Load state
	state, err := loadState()
	if err != nil {
		return fmt.Errorf("failed to load state: %w", err)
	}

	// Print status information
	fmt.Printf("State: %s\n", getStateName(state))
	fmt.Printf("RevertStreak: %d\n", state.RevertStreak)
	fmt.Printf("LastCommit: %s\n", state.LastCommitTime.Format(time.RFC3339))
	fmt.Printf("FailingTests: %v\n", state.FailingTests)

	return nil
}

// getStateName returns a human-readable state name
func getStateName(state *state.State) string {
	if state.IsRed() {
		return "RED"
	}
	return "GREEN"
}