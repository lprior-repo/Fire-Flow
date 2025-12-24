package utils

import (
	"os"
	"path/filepath"
	"time"

	"github.com/lprior-repo/Fire-Flow/internal/config"
	"github.com/lprior-repo/Fire-Flow/internal/state"
)

// TCRBasePath is the base directory name for TCR state and config
const TCRBasePath = ".opencode/tcr"

// GetTCRPath returns the TCR path.
// It uses the FIRE_FLOW_ROOT environment variable if set, otherwise uses the current working directory.
func GetTCRPath() string {
	root := os.Getenv("FIRE_FLOW_ROOT")
	if root == "" {
		// Fall back to current working directory
		root, _ = os.Getwd()
	}
	return filepath.Join(root, TCRBasePath)
}

// GetConfigPath returns the config file path
func GetConfigPath() string {
	return filepath.Join(GetTCRPath(), "config.yml")
}

// GetStatePath returns the state file path
func GetStatePath() string {
	return filepath.Join(GetTCRPath(), "state.json")
}

// CreateDefaultConfig creates and saves a default configuration
func CreateDefaultConfig(configPath string) error {
	cfg := config.DefaultConfig()
	return cfg.SaveToFile(configPath)
}

// CreateDefaultState creates and saves a default state
func CreateDefaultState(statePath string) error {
	st := state.NewState()
	return st.SaveToFile(statePath)
}

// LoadStateWithValidation loads state and ensures proper initialization
func LoadStateWithValidation() (*state.State, error) {
	st, err := state.LoadStateFromFile(GetStatePath())
	if err != nil {
		return nil, err
	}

	// Ensure the ActiveMounts array is properly initialized
	if st.ActiveMounts == nil {
		st.ActiveMounts = []state.ActiveMount{}
	}

	return st, nil
}

// GetStateName returns a human-readable state name based on test results
func GetStateName(s *state.State) string {
	if s != nil && !s.HasPassedTests() {
		return "RED"
	}
	return "GREEN"
}

// FormatTime formats a time for display
func FormatTime(t time.Time) string {
	return t.Format("2006-01-02 15:04:05")
}
