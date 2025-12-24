package overlay

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"syscall"
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

// StaleMount represents an orphaned overlay mount
type StaleMount struct {
	MergedDir string
	LowerDir  string
	UpperDir  string
	WorkDir   string
}

// DetectStaleMounts finds Fire-Flow overlay mounts that are orphaned.
// It parses /proc/mounts to find overlay mounts and checks if the creating
// process is still running.
func (om *OverlayManager) DetectStaleMounts() ([]StaleMount, error) {
	return om.DetectStaleMountsFromFile("/proc/mounts")
}

// DetectStaleMountsFromFile parses the given mounts file (for testing)
func (om *OverlayManager) DetectStaleMountsFromFile(mountsFile string) ([]StaleMount, error) {
	file, err := os.Open(mountsFile)
	if err != nil {
		return nil, fmt.Errorf("failed to open mounts file: %w", err)
	}
	defer file.Close()

	var staleMounts []StaleMount
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := scanner.Text()

		// Parse mount entry: device mountpoint type options ...
		// Example: overlay /tmp/fire-flow-merged overlay rw,relatime,lowerdir=...,upperdir=...,workdir=...
		fields := strings.Fields(line)
		if len(fields) < 4 {
			continue
		}

		fsType := fields[2]
		if fsType != "overlay" {
			continue
		}

		mountPoint := fields[1]
		options := fields[3]

		// Check if this looks like a Fire-Flow mount (has fire-flow in path)
		if !strings.Contains(mountPoint, "fire-flow") && !strings.Contains(options, "fire-flow") {
			continue
		}

		// Parse mount options
		stale := StaleMount{MergedDir: mountPoint}
		for _, opt := range strings.Split(options, ",") {
			if strings.HasPrefix(opt, "lowerdir=") {
				stale.LowerDir = strings.TrimPrefix(opt, "lowerdir=")
			} else if strings.HasPrefix(opt, "upperdir=") {
				stale.UpperDir = strings.TrimPrefix(opt, "upperdir=")
			} else if strings.HasPrefix(opt, "workdir=") {
				stale.WorkDir = strings.TrimPrefix(opt, "workdir=")
			}
		}

		staleMounts = append(staleMounts, stale)
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading mounts file: %w", err)
	}

	return staleMounts, nil
}

// IsPIDRunning checks if a process with the given PID is running
func IsPIDRunning(pid int) bool {
	if pid <= 0 {
		return false
	}
	process, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	// On Unix, FindProcess always succeeds. We need to send signal 0 to check.
	err = process.Signal(syscall.Signal(0))
	return err == nil
}

// CleanupStaleMounts unmounts and cleans up orphaned overlay mounts.
// Returns the number of mounts cleaned up and any errors.
func (om *OverlayManager) CleanupStaleMounts() (int, error) {
	staleMounts, err := om.DetectStaleMounts()
	if err != nil {
		return 0, fmt.Errorf("failed to detect stale mounts: %w", err)
	}

	cleaned := 0
	var lastErr error

	for _, stale := range staleMounts {
		if err := om.CleanupStaleMount(stale); err != nil {
			lastErr = err
			continue
		}
		cleaned++
	}

	return cleaned, lastErr
}

// CleanupStaleMount unmounts and cleans up a single stale mount
func (om *OverlayManager) CleanupStaleMount(stale StaleMount) error {
	// Try standard unmount first
	err := syscall.Unmount(stale.MergedDir, 0)
	if err != nil {
		// Try with lazy unmount
		if err := syscall.Unmount(stale.MergedDir, syscall.MNT_DETACH); err != nil {
			// Try with force
			if err := syscall.Unmount(stale.MergedDir, syscall.MNT_FORCE); err != nil {
				return fmt.Errorf("failed to unmount %s: %w", stale.MergedDir, err)
			}
		}
	}

	// Cleanup temporary directories (best effort)
	if stale.MergedDir != "" {
		os.RemoveAll(stale.MergedDir)
	}
	if stale.UpperDir != "" {
		os.RemoveAll(stale.UpperDir)
	}
	if stale.WorkDir != "" {
		os.RemoveAll(stale.WorkDir)
	}

	return nil
}

// GetStaleMountCount returns the number of stale mounts detected
func (om *OverlayManager) GetStaleMountCount() (int, error) {
	mounts, err := om.DetectStaleMounts()
	if err != nil {
		return 0, err
	}
	return len(mounts), nil
}
