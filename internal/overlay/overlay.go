package overlay

import (
	"fmt"
	"os"
	"time"
)

// OverlayManager handles overlay operations and provides a high-level interface
type OverlayManager struct {
	fakeMounter   *FakeMounter
	kernelMounter *KernelMounter
}

// NewOverlayManager creates a new overlay manager
func NewOverlayManager() *OverlayManager {
	return &OverlayManager{
		fakeMounter:   NewFakeMounter(),
		kernelMounter: NewKernelMounter(),
	}
}

// GetMounter returns a mounter of the specified type
func (om *OverlayManager) GetMounter(mounterType string) Mounter {
	switch mounterType {
	case "fake":
		return om.fakeMounter
	case "kernel":
		return om.kernelMounter
	default:
		return nil
	}
}

// ValidateMountConfig validates the mount configuration
func (om *OverlayManager) ValidateMountConfig(config MountConfig) error {
	if config.LowerDir == "" {
		return fmt.Errorf("lowerdir required")
	}
	if config.UpperDir == "" {
		return fmt.Errorf("upperdir required")
	}
	if config.WorkDir == "" {
		return fmt.Errorf("workdir required")
	}
	if config.MergedDir == "" {
		return fmt.Errorf("mergeddir required")
	}

	// Check that lower directory exists
	if _, err := os.Stat(config.LowerDir); os.IsNotExist(err) {
		return fmt.Errorf("lower directory does not exist: %s", config.LowerDir)
	}

	return nil
}

// CreateTempDirs creates temporary directories for overlay
func (om *OverlayManager) CreateTempDirs(config *MountConfig) error {
	// Create upper directory
	if err := os.MkdirAll(config.UpperDir, 0700); err != nil {
		return fmt.Errorf("failed to create upperdir: %w", err)
	}

	// Create work directory
	if err := os.MkdirAll(config.WorkDir, 0700); err != nil {
		os.RemoveAll(config.UpperDir)
		return fmt.Errorf("failed to create workdir: %w", err)
	}

	// Create merged directory
	if err := os.MkdirAll(config.MergedDir, 0700); err != nil {
		os.RemoveAll(config.UpperDir)
		os.RemoveAll(config.WorkDir)
		return fmt.Errorf("failed to create mergeddir: %w", err)
	}

	return nil
}

// CleanupTempDirs removes temporary directories
func (om *OverlayManager) CleanupTempDirs(config MountConfig) error {
	// Cleanup temporary directories (best effort)
	os.RemoveAll(config.MergedDir)
	os.RemoveAll(config.UpperDir)
	os.RemoveAll(config.WorkDir)
	return nil
}

// MountWithCleanup mounts an overlay and ensures cleanup on error
func (om *OverlayManager) MountWithCleanup(config MountConfig) (*OverlayMount, error) {
	// Validate config
	if err := om.ValidateMountConfig(config); err != nil {
		return nil, fmt.Errorf("invalid config: %w", err)
	}

	// Create temporary directories
	if err := om.CreateTempDirs(&config); err != nil {
		return nil, fmt.Errorf("failed to create temp dirs: %w", err)
	}

	// Create mounter and mount
	mounter := om.GetMounter("kernel")
	if mounter == nil {
		return nil, fmt.Errorf("no valid mounter found")
	}

	mount, err := mounter.Mount(config)
	if err != nil {
		// Cleanup on mount failure
		om.CleanupTempDirs(config)
		return nil, fmt.Errorf("mount failed: %w", err)
	}

	return mount, nil
}

// GetOverlayMountPath returns the merged directory path for a given mount
func (om *OverlayManager) GetOverlayMountPath(mount *OverlayMount) string {
	if mount == nil {
		return ""
	}
	return mount.Config.MergedDir
}

// GetOverlayUpperDir returns the upper directory path for a given mount
func (om *OverlayManager) GetOverlayUpperDir(mount *OverlayMount) string {
	if mount == nil {
		return ""
	}
	return mount.Config.UpperDir
}

// GetOverlayWorkDir returns the work directory path for a given mount
func (om *OverlayManager) GetOverlayWorkDir(mount *OverlayMount) string {
	if mount == nil {
		return ""
	}
	return mount.Config.WorkDir
}

// GetOverlayLowerDir returns the lower directory path for a given mount
func (om *OverlayManager) GetOverlayLowerDir(mount *OverlayMount) string {
	if mount == nil {
		return ""
	}
	return mount.Config.LowerDir
}

// FormatMountInfo returns a formatted string with mount information
func (om *OverlayManager) FormatMountInfo(mount *OverlayMount) string {
	if mount == nil {
		return "No mount information"
	}

	return fmt.Sprintf("Mount Info:\n"+
		"  LowerDir: %s\n"+
		"  UpperDir: %s\n"+
		"  WorkDir: %s\n"+
		"  MergedDir: %s\n"+
		"  MountedAt: %s\n"+
		"  PID: %d",
		mount.Config.LowerDir,
		mount.Config.UpperDir,
		mount.Config.WorkDir,
		mount.Config.MergedDir,
		mount.MountedAt.Format(time.RFC3339),
		mount.PID)
}
