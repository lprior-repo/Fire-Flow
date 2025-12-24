package tddgate

import (
	"fmt"

	"github.com/lprior-repo/Fire-Flow/internal/config"
	"github.com/lprior-repo/Fire-Flow/internal/teststate"
)

// ErrMultipleTestsExecuted is returned when more than one test was run in a single TCR cycle
var ErrMultipleTestsExecuted = fmt.Errorf("TCR violation: multiple tests executed in single cycle")

// TddGate represents the TDD gate system
type TddGate struct {
	config    *config.Config
	testState *teststate.TestStateDetector
	// SingleTestMode enforces that only one test can be run per TCR cycle
	// This prevents AI agents from "shotgunning" multiple tests at once
	SingleTestMode bool
}

// NewTddGate creates a new TDD gate instance
func NewTddGate(cfg *config.Config) *TddGate {
	return &TddGate{
		config:         cfg,
		testState:      teststate.NewTestStateDetector(),
		SingleTestMode: true, // Default to enforcing single test mode
	}
}

// NewTddGateWithOptions creates a new TDD gate with custom options
func NewTddGateWithOptions(cfg *config.Config, singleTestMode bool) *TddGate {
	return &TddGate{
		config:         cfg,
		testState:      teststate.NewTestStateDetector(),
		SingleTestMode: singleTestMode,
	}
}

// CheckGate evaluates whether to allow or block implementation based on test results
// Returns true if the gate passes (implementation allowed), false if blocked
func (g *TddGate) CheckGate() (bool, string, error) {
	// This is a simplified version - in a real implementation, this would
	// check the current state of the system
	// For now, we'll just return that the gate passes (implementation allowed)
	// This is just a placeholder for what would be the core logic

	// In a real system, this would check if the system is in a GREEN or RED state
	// and make a decision based on that

	return true, "TDD gate logic: Implementation is allowed (simplified for now)", nil
}

// RunTests executes the configured test command and returns the result
func (g *TddGate) RunTests() (*teststate.TestResult, error) {
	// This is a simplified implementation that just creates a mock result
	// A real implementation would execute the actual command

	// Create a mock result for testing purposes
	result := &teststate.TestResult{
		Output:        "Mock test output",
		Passed:        true,
		Duration:      g.config.Timeout,
		ExecutedTests: []string{"MockTest"}, // Single test for TCR compliance
	}

	return result, nil
}

// RunAndCheckGate executes tests and then checks the TDD gate
func (g *TddGate) RunAndCheckGate() (bool, *teststate.TestResult, string, error) {
	// Run tests
	testResult, err := g.RunTests()
	if err != nil {
		return false, testResult, "", err
	}

	// Enforce single test mode if enabled
	if g.SingleTestMode {
		if err := g.ValidateSingleTest(testResult); err != nil {
			return false, testResult, err.Error(), err
		}
	}

	// Check the gate
	passed, message, err := g.CheckGate()
	if err != nil {
		return false, testResult, "", err
	}

	return passed, testResult, message, nil
}

// ValidateSingleTest checks that only one test was executed
// Returns an error if multiple tests were run (TCR violation)
func (g *TddGate) ValidateSingleTest(result *teststate.TestResult) error {
	if result == nil {
		return fmt.Errorf("no test result provided")
	}

	executedCount := len(result.ExecutedTests)

	if executedCount == 0 {
		return fmt.Errorf("TCR violation: no tests were executed")
	}

	if executedCount > 1 {
		return fmt.Errorf("%w: ran %d tests (%v), expected 1",
			ErrMultipleTestsExecuted, executedCount, result.ExecutedTests)
	}

	return nil
}

// GetExecutedTestCount returns the number of tests that were executed
func (g *TddGate) GetExecutedTestCount(result *teststate.TestResult) int {
	if result == nil {
		return 0
	}
	return len(result.ExecutedTests)
}
