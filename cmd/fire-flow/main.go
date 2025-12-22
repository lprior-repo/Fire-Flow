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
	default:
		fmt.Printf("Unknown command: %s\n", command)
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("Usage: fire-flow <command> [args]")
	fmt.Println("Available commands:")
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

// isTestFile checks if a file path matches test patterns
func isTestFile(filePath string, patterns []string) bool {
	for _, pattern := range patterns {
		// Simple glob pattern matching
		if matched, err := filepath.Match(pattern, filepath.Base(filePath)); err == nil && matched {
			return true
		}
		// If it's a regex pattern (like _test\\.go$), we need to handle it differently
		if strings.Contains(pattern, "\\") {
			// For now, we'll check if it's a test file by checking if it contains _test.go
			if strings.Contains(filepath.Base(filePath), "_test.go") {
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
	
	// Simple parsing of go test -json output
	lines := strings.Split(output, "\n")
	for _, line := range lines {
		if strings.Contains(line, `"Action":"fail"`) {
			// Extract test name from JSON
			// This is a simplified version - in practice, you'd parse the JSON properly
			if strings.Contains(line, `"Test":`) {
				// Extract test name (this is a placeholder implementation)
				failedTests = append(failedTests, "unknown_test")
			}
		}
	}
	
	return failedTests
}

// updateState updates the state based on test results
func updateState(result *TestResult) error {
	// Load state
	state, err := loadState()
	if err != nil {
		return err
	}

	// Update failing tests
	state.SetFailingTests(result.FailedTests)

	// Save updated state
	statePath := filepath.Join(".opencode", "tcr", "state.json")
	return state.SaveToFile(statePath)
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
	state, err := loadState()
	if err != nil {
		return err
	}

	// Reset revert streak
	state.ResetRevertStreak()

	// Update last commit time
	state.LastCommitTime = time.Now()

	// Save updated state
	statePath := filepath.Join(".opencode", "tcr", "state.json")
	return state.SaveToFile(statePath)
}

// updateStateRevert updates state after a revert
func updateStateRevert() error {
	// Load state
	state, err := loadState()
	if err != nil {
		return err
	}

	// Increment revert streak
	state.IncrementRevertStreak()

	// Save updated state
	statePath := filepath.Join(".opencode", "tcr", "state.json")
	return state.SaveToFile(statePath)
}

// loadConfig loads configuration from the default location
func loadConfig() (*config.Config, error) {
	configPath := filepath.Join(".opencode", "tcr", "config.yml")
	return config.LoadFromFile(configPath)
}

// loadState loads state from the default location
func loadState() (*state.State, error) {
	statePath := filepath.Join(".opencode", "tcr", "state.json")
	return state.LoadStateFromFile(statePath)
}