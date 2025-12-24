package overlay

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestOverlayManager_Create tests creating an overlay manager
func TestOverlayManager_Create(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()

	// Act & Assert
	assert.NotNil(t, manager)
	assert.NotNil(t, manager.fakeMounter)
	assert.NotNil(t, manager.kernelMounter)
}

// TestOverlayManager_GetMounter tests getting the correct mounter
func TestOverlayManager_GetMounter(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()

	// Act
	fakeMounter := manager.GetMounter("fake")
	kernelMounter := manager.GetMounter("kernel")

	// Assert
	assert.NotNil(t, fakeMounter)
	assert.NotNil(t, kernelMounter)
	assert.IsType(t, &FakeMounter{}, fakeMounter)
	assert.IsType(t, &KernelMounter{}, kernelMounter)
}

// TestOverlayManager_GetMounter_InvalidType tests getting invalid mounter type
func TestOverlayManager_GetMounter_InvalidType(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()

	// Act
	mounter := manager.GetMounter("invalid")

	// Assert
	assert.Nil(t, mounter)
}
