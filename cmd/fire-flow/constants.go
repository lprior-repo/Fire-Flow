package main

import (
	"path/filepath"
)

// TCR Enforcer configuration paths and constants
const (
	// OpenCodeDir is the root directory for TCR configuration and state
	OpenCodeDir = ".opencode"
	// TCRDir is the subdirectory for TCR enforcer files
	TCRDir = "tcr"
	// ConfigFileName is the name of the TCR configuration file
	ConfigFileName = "config.yml"
	// StateFileName is the name of the TCR state file
	StateFileName = "state.json"
)

// GetTCRPath returns the full path to the TCR configuration directory
func GetTCRPath() string {
	return OpenCodeDir + "/" + TCRDir
}

// GetConfigPath returns the full path to the config file
func GetConfigPath() string {
	return filepath.Join(GetTCRPath(), ConfigFileName)
}

// GetStatePath returns the full path to the state file
func GetStatePath() string {
	return filepath.Join(GetTCRPath(), StateFileName)
}
