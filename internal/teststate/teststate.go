package teststate

import (
	"encoding/json"
	"strings"
)

// TestResult represents the result of test execution
type TestResult struct {
	// Passed indicates whether all tests passed
	Passed bool `json:"passed"`
	// FailedTests contains the list of failed test names
	FailedTests []string `json:"failedTests"`
	// ExecutedTests contains the list of all tests that were executed
	// Used for single-test enforcement in TCR workflow
	ExecutedTests []string `json:"executedTests"`
	// Duration is the test execution time in seconds
	Duration int `json:"duration"`
	// Output contains the raw test output
	Output string `json:"output"`
}

// TestStateDetector provides functionality for detecting test execution state
type TestStateDetector struct{}

// NewTestStateDetector creates a new test state detector
func NewTestStateDetector() *TestStateDetector {
	return &TestStateDetector{}
}

// ParseGoTestOutput parses the output of "go test -json" command
// Returns a TestResult struct with details about test execution
func (t *TestStateDetector) ParseGoTestOutput(output string) (*TestResult, error) {
	result := &TestResult{
		Output:        output,
		FailedTests:   []string{},
		ExecutedTests: []string{},
	}

	// Track unique test names that were executed
	executedSet := make(map[string]bool)

	// Parse go test -json output
	lines := strings.Split(output, "\n")
	for _, line := range lines {
		// Skip empty lines (including whitespace-only lines)
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		// Parse JSON line for test events
		var event map[string]any
		if err := json.Unmarshal([]byte(line), &event); err != nil {
			// Skip lines that aren't valid JSON
			continue
		}

		action, ok := event["Action"].(string)
		if !ok {
			continue
		}

		// Track executed tests (on "run" action)
		if action == "run" {
			if testName, ok := event["Test"].(string); ok && testName != "" {
				if !executedSet[testName] {
					executedSet[testName] = true
					result.ExecutedTests = append(result.ExecutedTests, testName)
				}
			}
		}

		// Track failed tests (on "fail" action)
		if action == "fail" {
			if testName, ok := event["Test"].(string); ok && testName != "" {
				result.FailedTests = append(result.FailedTests, testName)
			}
		}
	}

	// If we found any failures, tests didn't pass
	result.Passed = len(result.FailedTests) == 0

	return result, nil
}

// ExtractFailedTests parses test output to extract failed test names
// This is a simplified version that works with "go test -json" output
func (t *TestStateDetector) ExtractFailedTests(output string) []string {
	var failedTests []string

	// Parse go test -json output
	lines := strings.Split(output, "\n")
	for _, line := range lines {
		// Skip empty lines (including whitespace-only lines)
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		// Parse JSON line for test events
		var event map[string]any
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

// IsTestPassing determines if the tests are passing based on output
func (t *TestStateDetector) IsTestPassing(output string) (bool, []string, error) {
	result, err := t.ParseGoTestOutput(output)
	if err != nil {
		return false, nil, err
	}

	return result.Passed, result.FailedTests, nil
}

// GetTestResultFromOutput returns a TestResult from the raw output
func (t *TestStateDetector) GetTestResultFromOutput(output string) (*TestResult, error) {
	return t.ParseGoTestOutput(output)
}
