package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"time"

	"github.com/fsnotify/fsnotify"
	"github.com/lprior-repo/Fire-Flow/internal/config"
	"github.com/lprior-repo/Fire-Flow/internal/logging"
	"github.com/lprior-repo/Fire-Flow/internal/overlay"
	"github.com/lprior-repo/Fire-Flow/internal/state"
	"github.com/lprior-repo/Fire-Flow/internal/version"
	"github.com/spf13/viper"
)

var logger = logging.NewLogger()

// Command interface defines the contract for all CLI commands
type Command interface {
	Execute() error
}

func main() {
	logger.Info("%s starting...", version.Info())
	fmt.Printf("Welcome to %s!\n", version.Name)
	logger.Info("Fire-Flow is ready to orchestrate workflows")

	// Handle command parsing
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	command := os.Args[1]

	switch command {
	case "watch":
		executeCommand(&WatchCommand{}, "watch")
	case "gate":
		executeCommand(&GateCommand{}, "gate")
	case "init":
		executeCommand(&InitCommand{}, "init")
	case "status":
		executeCommand(&StatusCommand{}, "status")
	default:
		logger.Error("Unknown command: %s", command)
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("Usage: fire-flow <command> [args]")
	fmt.Println("Available commands:")
	fmt.Println("  init")
	fmt.Println("  status")
	fmt.Println("  watch")
	fmt.Println("  gate")
}

// executeCommand runs a command and handles errors consistently
func executeCommand(cmd Command, name string) {
	if err := cmd.Execute(); err != nil {
		logger.PrintError(fmt.Errorf("error in %s command: %w", name, err))
		os.Exit(1)
	}
}

// WatchCommand represents the watch command
type WatchCommand struct{}

// Execute runs the watch logic - watches for file changes and automatically runs tests
func (cmd *WatchCommand) Execute() error {
	// Load configuration
	cfg, err := loadConfig()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Initialize overlay manager with kernel mounter (requires sudo)
	overlayManager := overlay.NewOverlayManager(overlay.NewKernelMounter())

	// Create overlay mount
	wd, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("failed to get working directory: %w", err)
	}

	// Mount overlay
	mount, err := overlayManager.Mount(wd)
	if err != nil {
		return fmt.Errorf("failed to mount overlay: %w", err)
	}

	// Print mount info
	logger.Info("Overlay mounted at: %s", mount.Config.MergedDir)
	fmt.Printf("Overlay mounted at: %s\n", mount.Config.MergedDir)
	fmt.Printf("Lower directory: %s\n", mount.Config.LowerDir)
	fmt.Printf("Upper directory: %s\n", mount.Config.UpperDir)

	// Set up file watcher
	watcher, err := NewFileWatcher(mount.Config.MergedDir)
	if err != nil {
		overlayManager.Unmount(mount)
		return fmt.Errorf("failed to create file watcher: %w", err)
	}
	defer func() {
		watcher.Close()
		overlayManager.Unmount(mount)
		logger.Info("Overlay unmounted successfully")
	}()

	// Set up signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt)

	// Start watching for changes
	fmt.Println("Watching for file changes... (Press Ctrl+C to stop)")

	// Run initial test
	_, err = runTests(cfg.TestCommand, cfg.Timeout, true)
	if err != nil {
		logger.Error("Initial test run failed: %v", err)
		fmt.Printf("Initial test run failed: %v\n", err)
	}

	// Process file changes
	for {
		select {
		case <-watcher.Events():
			// Run tests on change
			logger.Info("File change detected, running tests...")
			fmt.Println("File change detected, running tests...")
			_, err := runTests(cfg.TestCommand, cfg.Timeout, false)
			if err != nil {
				logger.Error("Tests failed: %v", err)
				fmt.Printf("Tests failed: %v\n", err)
				// Discard changes if tests fail
				fmt.Println("Discarding changes...")
				logger.Info("Discarding changes...")
				if err := overlayManager.Discard(mount); err != nil {
					logger.Error("Error discarding changes: %v", err)
				}
			} else {
				fmt.Println("Tests passed, committing changes...")
				logger.Info("Tests passed, committing changes...")
				// Commit changes if tests pass
				if err := overlayManager.Commit(mount); err != nil {
					logger.Error("Error committing changes: %v", err)
				}
			}
		case err := <-watcher.Errors():
			logger.Error("Watcher error: %v", err)
		case <-sigChan:
			fmt.Println("\nReceived interrupt signal, shutting down...")
			logger.Info("Received interrupt signal, shutting down...")
			return nil
		}
	}
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
		logger.Error("Tests failed: %v", err)
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

// TestResult represents the result of test execution
type TestResult struct {
	Passed     bool     `json:"passed"`
	FailedTests []string `json:"failedTests"`
	Duration   int      `json:"duration"`
	Output     string   `json:"output"`
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
		logger.Info("Initial test run completed in %d seconds", result.Duration)
		if result.Passed {
			fmt.Println("All tests passed!")
		} else {
			logger.Error("Tests failed: %v", result.FailedTests)
			fmt.Printf("Tests failed: %v\n", result.FailedTests)
		}
	}

	// If there was an error, also print stderr
	if err != nil {
		if errBuf.Len() > 0 {
			logger.Error("Error output:\n%s", errBuf.String())
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

// InitCommand represents the init command
type InitCommand struct{}

// Execute runs the init command to set up Fire-Flow environment
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
		logger.Info("Created default config at %s", configPath)
	} else {
		logger.Info("Config file already exists at %s", configPath)
	}

	// Create default state file
	statePath := GetStatePath()
	if _, err := os.Stat(statePath); os.IsNotExist(err) {
		// Create default state
		st := state.NewState()
		if err := st.SaveToFile(statePath); err != nil {
			return fmt.Errorf("failed to create default state: %w", err)
		}
		logger.Info("Created default state at %s", statePath)
	} else {
		logger.Info("State file already exists at %s", statePath)
	}

	fmt.Println("Fire-Flow initialized successfully!")
	return nil
}

// StatusCommand represents the status command
type StatusCommand struct{}

// Execute runs the status command to show current state
func (cmd *StatusCommand) Execute() error {
	// Load state
	state, err := loadState()
	if err != nil {
		logger.Error("Failed to load state: %v", err)
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
	if state != nil && state.IsRed() {
		return "RED"
	}
	return "GREEN"
}

// FileWatcher provides file watching functionality using fsnotify
type FileWatcher struct {
	watcher *fsnotify.Watcher
	events  chan struct{}
	errors  chan error
	closed  chan struct{}
}

// NewFileWatcher creates a new file watcher for the given directory
func NewFileWatcher(dir string) (*FileWatcher, error) {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		logger.Error("Failed to create file watcher: %v", err)
		return nil, err
	}

	// Add the directory to watch
	err = watcher.Add(dir)
	if err != nil {
		watcher.Close()
		logger.Error("Failed to add directory to watcher: %v", err)
		return nil, err
	}

	w := &FileWatcher{
		watcher: watcher,
		events:  make(chan struct{}, 10),
		errors:  make(chan error, 10),
		closed:  make(chan struct{}),
	}

	// Start goroutine to handle fsnotify events
	go func() {
		defer func() {
			// Ensure watcher is closed even if there's an error
			watcher.Close()
			close(w.events)
			close(w.errors)
		}()
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					return
				}
				// Only trigger on write events for files in the watched directory
				if event.Op&fsnotify.Write == fsnotify.Write {
					select {
					case w.events <- struct{}{}:
					default:
						// Channel full, skip
					}
				}
			case err, ok := <-watcher.Errors:
				if !ok {
					return
				}
				logger.Error("File watcher error: %v", err)
				select {
				case w.errors <- err:
				default:
					// Channel full, skip
				}
			case <-w.closed:
				return
			}
		}
	}()

	return w, nil
}

// Events returns a channel that receives events when files change
func (w *FileWatcher) Events() <-chan struct{} {
	return w.events
}

// Errors returns a channel that receives errors
func (w *FileWatcher) Errors() <-chan error {
	return w.errors
}

// Close closes the file watcher and cleans up resources
func (w *FileWatcher) Close() error {
	close(w.closed)
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
	v.AddConfigPath(GetTCRPath())

	// Try to read config file
	if err := v.ReadInConfig(); err != nil {
		// If config file doesn't exist, return default config
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			logger.Error("Error reading config file: %v", err)
			return nil, fmt.Errorf("error reading config file: %w", err)
		}
		logger.Info("Config file not found, using defaults")
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

// loadState loads state from the default location
func loadState() (*state.State, error) {
	st, err := state.LoadStateFromFile(GetStatePath())
	if err != nil {
		logger.Error("Failed to load state: %v", err)
		return nil, err
	}

	// Ensure the failingTests array is properly initialized
	if st.FailingTests == nil {
		st.FailingTests = []string{}
	}

	return st, nil
}