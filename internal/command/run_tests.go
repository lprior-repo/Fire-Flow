package command

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/lprior-repo/Fire-Flow/internal/teststate"
)

// RunTestsCommand represents the run-tests command
// This command executes the test suite with timeout handling
type RunTestsCommand struct {
	Timeout int
}

// Execute runs the run-tests command
// It executes the configured test command with timeout handling
func (cmd *RunTestsCommand) Execute() error {
	// Load configuration
	cfg, err := loadConfig()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// If timeout is specified in command, use it; otherwise use config timeout
	timeoutSeconds := cfg.Timeout
	if cmd.Timeout > 0 {
		timeoutSeconds = cmd.Timeout
	}

	// Execute tests with timeout
	result, err := runTestsCommand(cfg.TestCommand, timeoutSeconds)
	if err != nil {
		return fmt.Errorf("tests failed: %w", err)
	}

	// Print test results
	if result.Passed {
		fmt.Println("All tests passed!")
	} else {
		fmt.Printf("Tests failed. Failed tests: %v\n", result.FailedTests)
	}

	// Print duration
	fmt.Printf("Test execution completed in %d seconds\n", result.Duration)

	return nil
}

// runTestsCommand executes the test command with timeout
func runTestsCommand(testCommand string, timeoutSeconds int) (*teststate.TestResult, error) {
	// Create a command to execute the test command
	cmd := exec.Command("sh", "-c", testCommand)

	// Capture output
	var stdout, stderr strings.Builder
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	// Run the test command with timeout
	done := make(chan error, 1)
	go func() {
		done <- cmd.Run()
	}()

	select {
	case <-time.After(time.Duration(timeoutSeconds) * time.Second):
		return nil, fmt.Errorf("test execution timed out after %d seconds", timeoutSeconds)
	case err := <-done:
		if err != nil {
			// Get the combined output
			output := stdout.String() + stderr.String()

			result := &teststate.TestResult{
				Output:   output,
				Duration: timeoutSeconds,
				Passed:   false,
			}

			// If there was an error, also print stderr
			if stderr.Len() > 0 {
				fmt.Printf("Error output:\n%s\n", stderr.String())
			}
			return result, fmt.Errorf("test execution failed: %w", err)
		}
	}

	// Get the combined output
	output := stdout.String() + stderr.String()

	result := &teststate.TestResult{
		Output:   output,
		Duration: timeoutSeconds,
	}

	// Parse test results (this would be more robust in a real implementation)
	testDetector := teststate.NewTestStateDetector()
	testResult, parseErr := testDetector.GetTestResultFromOutput(output)
	if parseErr == nil {
		result.Passed = testResult.Passed
		result.FailedTests = testResult.FailedTests
	} else {
		// If we can't parse, assume test passed if no error occurred
		result.Passed = true // Since we got here without error
	}

	return result, nil
}
