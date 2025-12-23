package logging

import (
	"fmt"
	"log"
	"os"
)

// Logger provides standardized logging for the CLI
type Logger struct {
	logger *log.Logger
}

// NewLogger creates a new logger with standardized formatting
func NewLogger() *Logger {
	return &Logger{
		logger: log.New(os.Stdout, "", log.LstdFlags),
	}
}

// Info logs informational messages
func (l *Logger) Info(format string, args ...interface{}) {
	l.logger.Printf("[INFO] "+format, args...)
}

// Warn logs warning messages
func (l *Logger) Warn(format string, args ...interface{}) {
	l.logger.Printf("[WARN] "+format, args...)
}

// Error logs error messages
func (l *Logger) Error(format string, args ...interface{}) {
	l.logger.Printf("[ERROR] "+format, args...)
}

// Debug logs debug messages (only shown when debug flag is enabled)
func (l *Logger) Debug(format string, args ...interface{}) {
	// For now, we'll treat debug as info, but this can be extended
	l.logger.Printf("[DEBUG] "+format, args...)
}

// Fatal logs error and exits the program
func (l *Logger) Fatal(format string, args ...interface{}) {
	l.logger.Fatalf("[FATAL] "+format, args...)
}

// PrintError prints an error message to stderr with standardized formatting
func (l *Logger) PrintError(err error) {
	fmt.Fprintf(os.Stderr, "[ERROR] %v\n", err)
}

// PrintUserError prints a user-friendly error message to stderr
func (l *Logger) PrintUserError(err error) {
	// For now, we'll use the same format as PrintError
	// In the future, we could implement more sophisticated user-friendly error handling
	fmt.Fprintf(os.Stderr, "[ERROR] %v\n", err)
}