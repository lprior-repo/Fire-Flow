package logging

import (
	"bytes"
	"errors"
	"log"
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestLogger(t *testing.T) {
	// Create a buffer to capture log output
	var buf bytes.Buffer

	// Create a logger with our custom writer
	logger := &Logger{
		logger: log.New(&buf, "", 0), // No prefix or flags for clean output
	}

	// Test Info logging
	logger.Info("Test info message")
	output := buf.String()
	if !strings.Contains(output, "[INFO] Test info message") {
		t.Errorf("Expected [INFO] prefix in info log, got: %s", output)
	}

	// Clear buffer
	buf.Reset()

	// Test Error logging
	logger.Error("Test error message")
	output = buf.String()
	if !strings.Contains(output, "[ERROR] Test error message") {
		t.Errorf("Expected [ERROR] prefix in error log, got: %s", output)
	}

	// Clear buffer
	buf.Reset()

	// Test Warn logging
	logger.Warn("Test warn message")
	output = buf.String()
	if !strings.Contains(output, "[WARN] Test warn message") {
		t.Errorf("Expected [WARN] prefix in warn log, got: %s", output)
	}

	// Clear buffer
	buf.Reset()

	// Test Debug logging
	logger.Debug("Test debug message")
	output = buf.String()
	if !strings.Contains(output, "[DEBUG] Test debug message") {
		t.Errorf("Expected [DEBUG] prefix in debug log, got: %s", output)
	}
}

func TestNewLogger(t *testing.T) {
	logger := NewLogger()
	assert.NotNil(t, logger)
	assert.NotNil(t, logger.logger)
}

func TestLogger_FormatArgs(t *testing.T) {
	var buf bytes.Buffer
	logger := &Logger{
		logger: log.New(&buf, "", 0),
	}

	// Test format arguments
	logger.Info("User %s has %d items", "alice", 42)
	output := buf.String()
	assert.Contains(t, output, "[INFO] User alice has 42 items")
}

func TestLogger_PrintError(t *testing.T) {
	// Save and restore stderr
	oldStderr := os.Stderr
	r, w, _ := os.Pipe()
	os.Stderr = w

	logger := NewLogger()
	testErr := errors.New("test error message")
	logger.PrintError(testErr)

	w.Close()
	os.Stderr = oldStderr

	var buf bytes.Buffer
	buf.ReadFrom(r)
	output := buf.String()
	assert.Contains(t, output, "[ERROR] test error message")
}

func TestLogger_PrintUserError(t *testing.T) {
	// Save and restore stderr
	oldStderr := os.Stderr
	r, w, _ := os.Pipe()
	os.Stderr = w

	logger := NewLogger()
	testErr := errors.New("user-facing error")
	logger.PrintUserError(testErr)

	w.Close()
	os.Stderr = oldStderr

	var buf bytes.Buffer
	buf.ReadFrom(r)
	output := buf.String()
	assert.Contains(t, output, "[ERROR] user-facing error")
}

func TestLogger_AllLogLevels(t *testing.T) {
	var buf bytes.Buffer
	logger := &Logger{
		logger: log.New(&buf, "", 0),
	}

	// Test each log level has correct prefix
	tests := []struct {
		name     string
		logFunc  func(string, ...interface{})
		expected string
	}{
		{"Info", logger.Info, "[INFO]"},
		{"Warn", logger.Warn, "[WARN]"},
		{"Error", logger.Error, "[ERROR]"},
		{"Debug", logger.Debug, "[DEBUG]"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			buf.Reset()
			tc.logFunc("test message")
			assert.Contains(t, buf.String(), tc.expected)
		})
	}
}
