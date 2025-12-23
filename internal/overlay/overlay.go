package overlay

import (
	"fmt"
	"os"
	"time"
)

// OverlayManager provides high-level operations for managing overlays
type OverlayManager struct {
	mounter Mounter
}

// NewOverlayManager creates a new overlay manager
func NewOverlayManager(mounter Mounter) *OverlayManager {
	return &OverlayManager{
		mounter: mounter,
	}
}

// Mount creates and mounts an overlay filesystem
func (om *OverlayManager) Mount(lowerDir string) (*OverlayMount, error) {
	// Generate temporary directories for overlay
	upperDir, err := createTempDir("fire-flow-overlay-upper")
	if err != nil {
		return nil, fmt.Errorf("failed to create upper directory: %w", err)
	}

	workDir, err := createTempDir("fire-flow-overlay-work")
	if err != nil {
		return nil, fmt.Errorf("failed to create work directory: %w", err)
	}

	mergedDir, err := createTempDir("fire-flow-overlay-merged")
	if err != nil {
		return nil, fmt.Errorf("failed to create merged directory: %w", err)
	}

	// Create mount configuration
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  upperDir,
		WorkDir:   workDir,
		MergedDir: mergedDir,
	}

	// Mount using the mounter
	mount, err := om.mounter.Mount(config)
	if err != nil {
		// Cleanup on failure
		os.RemoveAll(upperDir)
		os.RemoveAll(workDir)
		os.RemoveAll(mergedDir)
		return nil, err
	}

	return mount, nil
}

// Unmount removes the overlay mount and cleans up
func (om *OverlayManager) Unmount(mount *OverlayMount) error {
	return om.mounter.Unmount(mount)
}

// Commit merges changes from upper to lower layer
func (om *OverlayManager) Commit(mount *OverlayMount) error {
	return om.mounter.Commit(mount)
}

// Discard removes upper layer without committing
func (om *OverlayManager) Discard(mount *OverlayMount) error {
	return om.mounter.Discard(mount)
}

// createTempDir creates a temporary directory with the given prefix
func createTempDir(prefix string) (string, error) {
	// Use the system temp directory with our prefix
	dir, err := os.MkdirTemp("", prefix)
	if err != nil {
		return "", err
	}
	
	// Make sure it's owned by the current user
	if err := os.Chmod(dir, 0700); err != nil {
		return "", err
	}
	
	return dir, nil
}

// GetMountInfo returns information about an active mount
func (om *OverlayManager) GetMountInfo(mount *OverlayMount) string {
	if mount == nil {
		return "No mount active"
	}
	
	return fmt.Sprintf("Mount: %s\nLower: %s\nUpper: %s\nWork: %s\nMerged: %s\nMounted At: %s",
		mount.Config.MergedDir,
		mount.Config.LowerDir,
		mount.Config.UpperDir,
		mount.Config.WorkDir,
		mount.Config.MergedDir,
		mount.MountedAt.Format(time.RFC3339))
}