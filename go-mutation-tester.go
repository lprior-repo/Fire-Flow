package main

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"
)

// This is a Go-based implementation for mutation testing in Fire-Flow
// It demonstrates how to properly set up and run mutation testing with concurrency

func main() {
	fmt.Println("=== Fire-Flow Mutation Testing Framework ===")
	
	// Check if go-mutest is installed
	if !isGoMutestInstalled() {
		fmt.Println("go-mutest not found. Installing...")
		if err := installGoMutest(); err != nil {
			fmt.Printf("Failed to install go-mutest: %v\n", err)
			fmt.Println("Continuing with manual configuration...")
		} else {
			fmt.Println("go-mutest installed successfully!")
		}
	}
	
	// Run mutation tests with concurrency
	fmt.Println("Running mutation tests with concurrency...")
	
	// Get number of available CPU cores
	numCPU := runtime.NumCPU()
	fmt.Printf("Using %d CPU cores for parallel execution\n", numCPU)
	
	// Run tests on different packages concurrently
	packages := []string{
		"./internal/...",
		"./cmd/...",
	}
	
	var wg sync.WaitGroup
	results := make(chan string, len(packages))
	
	// Run tests in parallel
	for _, pkg := range packages {
		wg.Add(1)
		go func(packagePath string) {
			defer wg.Done()
			result := runMutationTest(packagePath, numCPU)
			results <- result
		}(pkg)
	}
	
	// Close results channel when all goroutines are done
	go func() {
		wg.Wait()
		close(results)
	}()
	
	// Collect and display results
	allSuccess := true
	for result := range results {
		if strings.Contains(result, "ERROR") {
			allSuccess = false
			fmt.Printf("❌ %s\n", result)
		} else {
			fmt.Printf("✅ %s\n", result)
		}
	}
	
	if allSuccess {
		fmt.Println("🎉 All mutation tests completed successfully!")
	} else {
		fmt.Println("⚠️  Some mutation tests had errors")
		os.Exit(1)
	}
}

// isGoMutestInstalled checks if go-mutest is installed
func isGoMutestInstalled() bool {
	_, err := exec.LookPath("go-mutest")
	return err == nil
}

// installGoMutest attempts to install go-mutest
func installGoMutest() error {
	cmd := exec.Command("go", "install", "github.com/zimmski/go-mutest@latest")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("installation failed: %v - %s", err, strings.TrimSpace(string(output)))
	}
	return nil
}

// runMutationTest runs mutation testing on a specific package with concurrency
func runMutationTest(packagePath string, numCPU int) string {
	startTime := time.Now()
	
	// Build command with concurrency support
	cmd := exec.Command("go-mutest", "-config=mutation-test-config.yaml", fmt.Sprintf("-p=%d", numCPU), packagePath)
	
	// Capture output
	output, err := cmd.CombinedOutput()
	
	duration := time.Since(startTime)
	
	// Format result
	result := fmt.Sprintf("Package %s: %s", packagePath, strings.TrimSpace(string(output)))
	if err != nil {
		result = fmt.Sprintf("ERROR: Package %s: %v - %s", packagePath, err, strings.TrimSpace(string(output)))
	}
	
	return fmt.Sprintf("%s (%v)", result, duration)
}