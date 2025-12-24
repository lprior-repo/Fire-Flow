package command

import (
	"fmt"
	"os"
	"strings"

	"github.com/lprior-repo/Fire-Flow/internal/config"
	"github.com/lprior-repo/Fire-Flow/internal/state"
	"github.com/lprior-repo/Fire-Flow/internal/utils"
	"github.com/spf13/viper"
	"gopkg.in/yaml.v3"
)

// Command interface defines the structure for all Fire-Flow commands
type Command interface {
	Execute() error
}

// CommandFactory creates command instances
type CommandFactory struct{}

// NewCommand creates a new command instance based on the command name
func (f *CommandFactory) NewCommand(name string) (Command, error) {
	switch name {
	case "init":
		return &InitCommand{}, nil
	case "status":
		return &StatusCommand{}, nil
	case "watch":
		return &WatchCommand{}, nil
	case "gate":
		return &GateCommand{}, nil
	case "tdd-gate":
		return &TddGateCommand{}, nil
	default:
		return nil, fmt.Errorf("unknown command: %s", name)
	}
}

// InitCommand represents the init command
type InitCommand struct{}

// Execute runs the init command to set up Fire-Flow environment
func (cmd *InitCommand) Execute() error {
	// Create directories
	tcrPath := utils.GetTCRPath()
	if err := os.MkdirAll(tcrPath, 0755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", tcrPath, err)
	}

	// Create default config file
	configPath := utils.GetConfigPath()
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		// Create default config
		if err := utils.CreateDefaultConfig(configPath); err != nil {
			return fmt.Errorf("failed to create default config: %w", err)
		}
		fmt.Printf("Created default config at %s\n", configPath)
	} else {
		fmt.Printf("Config file already exists at %s\n", configPath)
	}

	// Create default state file
	statePath := utils.GetStatePath()
	if _, err := os.Stat(statePath); os.IsNotExist(err) {
		// Create default state
		if err := utils.CreateDefaultState(statePath); err != nil {
			return fmt.Errorf("failed to create default state: %w", err)
		}
		fmt.Printf("Created default state at %s\n", statePath)
	} else {
		fmt.Printf("State file already exists at %s\n", statePath)
	}

	fmt.Println("Fire-Flow initialized successfully!")
	return nil
}

// StatusCommand represents the status command
type StatusCommand struct{}

// Execute runs the status command to show current state
func (cmd *StatusCommand) Execute() error {
	// Load state
	state, err := utils.LoadStateWithValidation()
	if err != nil {
		return fmt.Errorf("failed to load state: %w", err)
	}

	// Print status information
	fmt.Printf("State: %s\n", utils.GetStateName(state))
	fmt.Printf("RevertStreak: %d\n", state.RevertStreak)
	fmt.Printf("LastCommit: %s\n", utils.FormatTime(state.LastCommitTime))
	fmt.Printf("FailingTests: %v\n", state.FailingTests)

	return nil
}

// GateCommand represents the gate command
type GateCommand struct{}

// Execute runs the gate logic - reads from stdin and writes to stdout for CI integration
func (cmd *GateCommand) Execute() error {
	// Load configuration
	cfg, err := loadConfig()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Read stdin for the gate command
	var input struct {
		Files []string `json:"files"`
	}

	decoder := json.NewDecoder(os.Stdin)
	if err := decoder.Decode(&input); err != nil {
		return fmt.Errorf("failed to decode stdin: %w", err)
	}

	// Run tests for the files
	result, err := runTests(cfg.TestCommand, cfg.Timeout, true)
	if err != nil {
		return fmt.Errorf("tests failed: %w", err)
	}

	// Output results to stdout for CI pipeline
	output := struct {
		Passed bool     `json:"passed"`
		Failed []string `json:"failed"`
	}{
		Passed: result.Passed,
		Failed: result.FailedTests,
	}

	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(output); err != nil {
		return fmt.Errorf("failed to encode output: %w", err)
	}

	return nil
}

// TddGateCommand represents the TDD gate command
type TddGateCommand struct{}

// Execute runs the TDD gate check - blocks implementation when tests pass (GREEN), allows when they fail (RED)
func (cmd *TddGateCommand) Execute() error {
	// Load state to check current TDD status
	state, err := utils.LoadStateWithValidation()
	if err != nil {
		return fmt.Errorf("failed to load state: %w", err)
	}

	// If tests are currently passing (GREEN state), block implementation
	if state.IsGreen() {
		return fmt.Errorf("TDD gate blocked: Tests are currently passing (GREEN state). Implementation is blocked until tests fail (RED state). Run tests to see current state.")
	}

	// If tests are currently failing (RED state), allow implementation
	fmt.Println("TDD gate passed: Tests are currently failing (RED state). Implementation is allowed.")
	return nil
}

// loadConfig loads configuration using Viper
func loadConfig() (*config.Config, error) {
	// Set up Viper configuration
	v := viper.New()

	// Set default values
	v.SetDefault("testCommand", "go test -json ./...")
	v.SetDefault("testPatterns", []string{"_test\\.go$"})
	v.SetDefault("protectedPaths", []string{"opencode.json", ".fire-flow"})
	v.SetDefault("timeout", 30)
	v.SetDefault("autoCommitMsg", "WIP")

	// Set config file name and path
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath(utils.GetTCRPath())

	// Try to read config file
	if err := v.ReadInConfig(); err != nil {
		// If config file doesn't exist, return default config
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("error reading config file: %w", err)
		}
	}

	// Create config from viper values
	cfg := &config.Config{
		TestCommand:    v.GetString("testCommand"),
		TestPatterns:   v.GetStringSlice("testPatterns"),
		ProtectedPaths: v.GetStringSlice("protectedPaths"),
		Timeout:        v.GetInt("timeout"),
		AutoCommitMsg:  v.GetString("autoCommitMsg"),
	}

	return cfg, nil
}

// TestResult represents the result of test execution
type TestResult struct {
	Passed      bool     `json:"passed"`
	FailedTests []string `json:"failedTests"`
	Duration    int      `json:"duration"`
	Output      string   `json:"output"`
}

// runTests executes the test command with timeout
func runTests(testCommand string, timeoutSeconds int, isInitial bool) (*TestResult, error) {
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

	// Print test results
	if isInitial {
		fmt.Printf("Initial test run completed in %d seconds\n", result.Duration)
		if result.Passed {
			fmt.Println("All tests passed!")
		} else {
			fmt.Printf("Tests failed: %v\n", result.FailedTests)
		}
	}

	// If there was an error, also print stderr
	if err != nil {
		if errBuf.Len() > 0 {
			fmt.Printf("Error output:\n%s\n", errBuf.String())
		}
		return result, fmt.Errorf("test execution failed: %w", err)
	}

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