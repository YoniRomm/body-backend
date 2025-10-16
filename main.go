package main

import (
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"strconv"
	"time"
)

func generateRandomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	result := make([]byte, length)
	for i := range result {
		result[i] = charset[r.Intn(len(charset))]
	}
	return string(result)
}

// Helper function to calculate absolute value
func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

func patternHandler(w http.ResponseWriter, r *http.Request) {
	// Extract headers
	patternBytesStr := r.Header.Get("X-Pattern-Bytes")
	patternCountStr := r.Header.Get("X-Pattern-Count")
	tokenizedCardNumber := r.Header.Get("X-Tokenized-Card-Number")
	requestId := r.Header.Get("X-Request-Id")

	// Validate required headers
	if patternBytesStr == "" || patternCountStr == "" || tokenizedCardNumber == "" {
		http.Error(w, "Missing required headers: X-Pattern-Bytes, X-Pattern-Count, X-Tokenized-Card-Number", http.StatusBadRequest)
		return
	}

	// Parse payload size from X-Pattern-Bytes
	payloadSize, err := strconv.Atoi(patternBytesStr)
	if err != nil || payloadSize < 0 {
		http.Error(w, "Invalid X-Pattern-Bytes: must be a non-negative integer representing payload size", http.StatusBadRequest)
		return
	}

	// Parse pattern count (keeping for compatibility)
	patternCount, err := strconv.Atoi(patternCountStr)
	if err != nil || patternCount < 0 {
		http.Error(w, "Invalid X-Pattern-Count: must be a non-negative integer", http.StatusBadRequest)
		return
	}

	// Calculate space needed for 3 occurrences of the card number
	cardNumberLength := len(tokenizedCardNumber)
	totalCardNumberBytes := cardNumberLength * 3

	// Ensure we have enough space for the card numbers
	if payloadSize < totalCardNumberBytes {
		http.Error(w, "Payload size too small to fit 3 occurrences of the tokenized card number", http.StatusBadRequest)
		return
	}

	// Generate random content for the entire payload first
	randomContent := generateRandomString(payloadSize)

	// Create a byte slice from the random content
	payload := []byte(randomContent)

	// Generate 3 random positions to insert the card number
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	positions := make([]int, 3)

	// Generate non-overlapping random positions
	for i := 0; i < patternCount; i++ {
		var position int
		validPosition := false
		attempts := 0

		for !validPosition && attempts < 100 {
			position = rng.Intn(payloadSize - cardNumberLength + 1)
			validPosition = true

			// Check if this position overlaps with existing positions
			for j := 0; j < i; j++ {
				if abs(position-positions[j]) < cardNumberLength {
					validPosition = false
					break
				}
			}
			attempts++
		}

		if !validPosition {
			// Fallback: distribute evenly
			position = (payloadSize/(patternCount+1))*(i+1) - cardNumberLength/2
			if position < 0 {
				position = 0
			}
			if position > payloadSize-cardNumberLength {
				position = payloadSize - cardNumberLength
			}
		}

		positions[i] = position
	}

	// Insert the card number at the calculated positions
	cardNumberBytes := []byte(tokenizedCardNumber)
	for _, position := range positions {
		copy(payload[position:position+cardNumberLength], cardNumberBytes)
	}

	// Set content type and response headers
	w.Header().Set("Content-Type", "text/plain")
	if requestId != "" {
		w.Header().Set("X-Request-Id", requestId)
	}
	w.WriteHeader(http.StatusOK)
	_, err = w.Write(payload)
	if err != nil {
		log.Printf("Error writing response: %v", err)
	}
}

func main() {
	// Register route handler
	http.HandleFunc("/generate", patternHandler)

	// Start server
	port := ":8080"
	fmt.Printf("Server starting on port %s\n", port)
	fmt.Println("Send POST/GET requests to http://localhost:8080/generate with headers:")
	fmt.Println("  X-Pattern-Bytes: <payload_size_in_bytes>")
	fmt.Println("  X-Pattern-Count: <number_for_compatibility>")
	fmt.Println("  X-Tokenized-Card-Number: <card_number_appears_3_times_randomly>")
	fmt.Println("  X-Request-Id: <optional_request_id_echoed_back>")

	log.Fatal(http.ListenAndServe(port, nil))
}
