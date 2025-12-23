package utils

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGetTCRPath(t *testing.T) {
	expected := "/home/lewis/.opencode/tcr"
	actual := GetTCRPath()
	assert.Equal(t, expected, actual)
}

func TestGetConfigPath(t *testing.T) {
	expected := filepath.Join(GetTCRPath(), "config.yml")
	actual := GetConfigPath()
	assert.Equal(t, expected, actual)
}

func TestGetStatePath(t *testing.T) {
	expected := filepath.Join(GetTCRPath(), "state.json")
	actual := GetStatePath()
	assert.Equal(t, expected, actual)
}