package state

import (
	"encoding/json"
	"os"
	"time"
)

// State represents the persistent enforcer state.
type State struct {
	Mode           string    `json:"mode"`
	RevertStreak   int       `json:"revertStreak"`
	FailingTests   []string  `json:"failingTests"`
	LastCommitTime time.Time `json:"lastCommitTime"`
}

// NewState creates a new state with default values.
func NewState() *State {
	return &State{
		Mode:           "both",
		RevertStreak:   0,
		FailingTests:   []string{},
		LastCommitTime: time.Now(),
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

// IncrementRevertStreak increments the revert streak counter.
func (s *State) IncrementRevertStreak() {
	s.RevertStreak++
}

// ResetRevertStreak resets the revert streak to zero.
func (s *State) ResetRevertStreak() {
	s.RevertStreak = 0
}

// SetFailingTests updates the list of failing test names.
func (s *State) SetFailingTests(tests []string) {
	s.FailingTests = tests
}

// IsRed returns true if there are failing tests (Red state).
func (s *State) IsRed() bool {
	return len(s.FailingTests) > 0
}

// IsGreen returns true if there are no failing tests (Green state).
func (s *State) IsGreen() bool {
	return len(s.FailingTests) == 0
}

// SetRed sets the state to red (failing tests)
func (s *State) SetRed() {
	s.FailingTests = []string{"TestExample"}
}

// SetGreen sets the state to green (no failing tests)
func (s *State) SetGreen() {
	s.FailingTests = []string{}
}
