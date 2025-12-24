package command

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/lprior-repo/Fire-Flow/internal/teststate"
)

// JSONOutput represents the structure for structured JSON output
type JSONOutput struct {
	// Version of the output format
	Version string `json:"version"`

	// Command that was executed
	Command string `json:"command"`

	// Success status of the operation
	Success bool `json:"success"`

	// Error message if operation failed
	Error string `json:"error,omitempty"`

	// Test results if applicable
	TestResult *teststate.TestResult `json:"testResult,omitempty"`

	// Timestamp of the operation
	Timestamp string `json:"timestamp"`
}

// OutputJSON outputs structured JSON format
func OutputJSON(output JSONOutput) error {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	return encoder.Encode(output)
}

// OutputTestResultAsJSON outputs test results in structured JSON format
func OutputTestResultAsJSON(result *teststate.TestResult, command string) error {
	output := JSONOutput{
		Version:    "1.0",
		Command:    command,
		Success:    result.Passed,
		TestResult: result,
		Timestamp:  fmt.Sprintf("%d", time.Now().Unix()),
	}

	return OutputJSON(output)
}

// OutputErrorAsJSON outputs an error in structured JSON format
func OutputErrorAsJSON(err error, command string) error {
	output := JSONOutput{
		Version:   "1.0",
		Command:   command,
		Success:   false,
		Error:     err.Error(),
		Timestamp: fmt.Sprintf("%d", time.Now().Unix()),
	}

	return OutputJSON(output)
}
