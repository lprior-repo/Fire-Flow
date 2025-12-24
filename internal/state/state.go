package state

import (
	"encoding/json"
	"os"
	"time"
)

// ActiveMount represents an active overlay mount in the state
type ActiveMount struct {
	MergedDir    string    `json:"mergedDir"`
	LowerDir     string    `json:"lowerDir"`
	MountedSince time.Time `json:"mountedSince"`
	PID          int       `json:"pid"`
}

// State represents the persistent overlay-first enforcer state.
// Version 2.0 - Complete replacement of legacy TCR state model.
type State struct {
	// Version indicates state format version for migrations
	Version string `json:"version"`

	// OverlayActive indicates if an overlay is currently mounted
	OverlayActive bool `json:"overlayActive"`

	// OverlayMountPath is the original project directory (lower dir)
	OverlayMountPath string `json:"overlayMountPath"`

	// OverlayUpperDir is the writable layer path
	OverlayUpperDir string `json:"overlayUpperDir"`

	// OverlayWorkDir is the OverlayFS work directory
	OverlayWorkDir string `json:"overlayWorkDir"`

	// OverlayMergedDir is the union mount point
	OverlayMergedDir string `json:"overlayMergedDir"`

	// OverlayMountedAt is when the overlay was mounted
	OverlayMountedAt time.Time `json:"overlayMountedAt"`

	// LastTestResult indicates if the last test run passed (true) or failed (false)
	LastTestResult bool `json:"lastTestResult"`

	// LastTestTime is when tests were last run
	LastTestTime time.Time `json:"lastTestTime"`

	// ActiveMounts tracks all active overlay mounts
	ActiveMounts []ActiveMount `json:"activeMounts"`
}

// NewState creates a new state with default values.
func NewState() *State {
	return &State{
		Version:          "2.0",
		OverlayActive:    false,
		OverlayMountPath: "",
		OverlayUpperDir:  "",
		OverlayWorkDir:   "",
		OverlayMergedDir: "",
		OverlayMountedAt: time.Time{},
		LastTestResult:   false,
		LastTestTime:     time.Time{},
		ActiveMounts:     []ActiveMount{},
	}
}

// SaveToFile persists the state to a JSON file.
func (s *State) SaveToFile(filePath string) error {
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filePath, data, 0644)
}

// LoadStateFromFile loads state from a JSON file.
// If the file doesn't exist, returns a new default state with no error.
func LoadStateFromFile(filePath string) (*State, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			// File doesn't exist, return default state
			return NewState(), nil
		}
		return nil, err
	}

	var state State
	if err := json.Unmarshal(data, &state); err != nil {
		return nil, err
	}
	return &state, nil
}

// SetOverlayMounted updates state when an overlay is mounted
func (s *State) SetOverlayMounted(lowerDir, upperDir, workDir, mergedDir string, pid int) {
	s.OverlayActive = true
	s.OverlayMountPath = lowerDir
	s.OverlayUpperDir = upperDir
	s.OverlayWorkDir = workDir
	s.OverlayMergedDir = mergedDir
	s.OverlayMountedAt = time.Now()

	// Add to active mounts
	s.ActiveMounts = append(s.ActiveMounts, ActiveMount{
		MergedDir:    mergedDir,
		LowerDir:     lowerDir,
		MountedSince: s.OverlayMountedAt,
		PID:          pid,
	})
}

// SetOverlayUnmounted updates state when an overlay is unmounted
func (s *State) SetOverlayUnmounted() {
	s.OverlayActive = false
	s.OverlayMountPath = ""
	s.OverlayUpperDir = ""
	s.OverlayWorkDir = ""
	s.OverlayMergedDir = ""
	s.OverlayMountedAt = time.Time{}
	s.ActiveMounts = []ActiveMount{}
}

// SetTestResult records the result of a test run
func (s *State) SetTestResult(passed bool) {
	s.LastTestResult = passed
	s.LastTestTime = time.Now()
}

// IsOverlayActive returns true if an overlay is currently mounted
func (s *State) IsOverlayActive() bool {
	return s.OverlayActive
}

// HasPassedTests returns true if the last test run passed
func (s *State) HasPassedTests() bool {
	return s.LastTestResult
}

// GetActiveMountCount returns the number of active mounts
func (s *State) GetActiveMountCount() int {
	return len(s.ActiveMounts)
}

// RemoveActiveMount removes a mount from the active mounts list by mergedDir
func (s *State) RemoveActiveMount(mergedDir string) {
	newMounts := make([]ActiveMount, 0, len(s.ActiveMounts))
	for _, m := range s.ActiveMounts {
		if m.MergedDir != mergedDir {
			newMounts = append(newMounts, m)
		}
	}
	s.ActiveMounts = newMounts
}

// GetStaleMounts returns mounts where the PID is no longer running
// checkPID is a function that returns true if the process is running
func (s *State) GetStaleMounts(checkPID func(int) bool) []ActiveMount {
	var stale []ActiveMount
	for _, m := range s.ActiveMounts {
		if !checkPID(m.PID) {
			stale = append(stale, m)
		}
	}
	return stale
}

// ClearStaleMounts removes mounts where the PID is no longer running
func (s *State) ClearStaleMounts(checkPID func(int) bool) int {
	var active []ActiveMount
	removed := 0
	for _, m := range s.ActiveMounts {
		if checkPID(m.PID) {
			active = append(active, m)
		} else {
			removed++
		}
	}
	s.ActiveMounts = active
	return removed
}
