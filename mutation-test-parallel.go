// Package main provides a parallel mutation testing approach for Fire-Flow
package main

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"
)

func main() {
	// Get number of CPU cores
	numCPU := runtime.NumCPU()
	fmt.Printf("Running mutation tests with %d parallel workers\n", numCPU)

	// Define packages to test
	packages := []string{
		"./internal/...",
		"./cmd/...",
	}

	// Create a wait group for goroutines
	var wg sync.WaitGroup
	results := make(chan string, len(packages)*2) // Buffer for results

	// Launch parallel mutation tests
	for _, pkg := range packages {
		wg.Add(1)
		go func(packagePath string) {
			defer wg.Done()
			runMutationTest(packagePath, results)
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

// runMutationTest runs mutation testing on a specific package
func runMutationTest(packagePath string, results chan<- string) {
	// Build the command
	cmd := exec.Command("go-mutest", "-config=mutation-test-config.yaml", packagePath)
	
	// Capture output
	output, err := cmd.CombinedOutput()
	
	// Format result
	result := fmt.Sprintf("Package %s: %s", packagePath, strings.TrimSpace(string(output)))
	if err != nil {
		result = fmt.Sprintf("ERROR: Package %s: %v - %s", packagePath, err, strings.TrimSpace(string(output)))
	}
	
	results <- result
}