package command

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/lprior-repo/Fire-Flow/internal/overlay"
	"github.com/lprior-repo/Fire-Flow/internal/utils"
)

// WatchCommand represents the watch command for overlay-based workflow
type WatchCommand struct{}

// Execute runs the watch command to orchestrate overlay workflow
func (cmd *WatchCommand) Execute() error {
	// Load configuration
	cfg, err := loadConfig()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Load state
	st, err := utils.LoadStateWithValidation()
	if err != nil {
		return fmt.Errorf("failed to load state: %w", err)
	}

	// Create overlay manager
	overlayManager := overlay.NewOverlayManager()

	// Get current working directory
	currentDir, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("failed to get current directory: %w", err)
	}

	// Create mount configuration - using current directory as lower dir
	// and creating temporary directories for upper, work, and merged
	mountConfig := overlay.MountConfig{
		LowerDir:  currentDir,
		UpperDir:  filepath.Join(utils.GetTCRPath(), "upper"),
		WorkDir:   filepath.Join(utils.GetTCRPath(), "work"),
		MergedDir: filepath.Join(utils.GetTCRPath(), "merged"),
	}

	// Mount overlay
	fmt.Println("Mounting overlay...")
	mount, err := overlayManager.MountWithCleanup(mountConfig)
	if err != nil {
		return fmt.Errorf("failed to mount overlay: %w", err)
	}

	fmt.Printf("Overlay mounted successfully at %s\n", mount.Config.MergedDir)
	fmt.Println("You are now in the overlay development environment.")
	fmt.Println("All changes you make in this directory will be in the overlay upper layer.")
	fmt.Println("When tests pass, changes will be committed to the real filesystem.")
	fmt.Println("When tests fail, changes will be discarded.")

	// Run initial test to establish baseline state
	fmt.Println("Running initial test suite...")
	testResult, err := runTests(cfg.TestCommand, cfg.Timeout, true)
	if err != nil {
		fmt.Printf("Initial tests failed: %v\n", err)
	} else {
		if testResult.Passed {
			fmt.Println("All tests passed (GREEN state)")
		} else {
			fmt.Println("Tests failed (RED state)")
		}
	}

	// Update state to show we're in watch mode with overlay active
	st.SetOverlayMounted(
		mountConfig.LowerDir,
		mountConfig.UpperDir,
		mountConfig.WorkDir,
		mountConfig.MergedDir,
		os.Getpid(),
	)
	st.SaveToFile(utils.GetStatePath())

	fmt.Println("Watch command completed - overlay is now active")
	fmt.Println("In a real implementation, this would continue monitoring for changes and running tests")

	return nil
}
