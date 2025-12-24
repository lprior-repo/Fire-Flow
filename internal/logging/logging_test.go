package logging

import (
	"bytes"
	"log"
	"strings"
	"testing"
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
