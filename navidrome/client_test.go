package navidrome

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetNowPlayingReturnsNilWhenEmpty(t *testing.T) {
	// Mock HTTP response
	mockResponse := map[string]interface{}{
		"subsonic-response": map[string]interface{}{
			"status": "ok",
			"nowPlaying": map[string]interface{}{
				"entry": []interface{}{},
			},
		},
	}

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(mockResponse)
	}))
	defer ts.Close()

	client := NewClient(ts.URL, "user", "pass")
	entry, err := client.GetNowPlaying()

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if entry != nil {
		t.Fatalf("expected nil entry, got %+v", entry)
	}
}

func TestGetNowPlayingReturnsValidEntry(t *testing.T) {
	// Mock HTTP response with one track
	mockResponse := map[string]interface{}{
		"subsonic-response": map[string]interface{}{
			"status": "ok",
			"nowPlaying": map[string]interface{}{
				"entry": []interface{}{
					map[string]interface{}{
						"id":       "song1",
						"title":    "Test Title",
						"artist":   "Test Artist",
						"album":    "Test Album",
						"coverArt": "cover1",
						"duration": float64(200),
					},
				},
			},
		},
	}

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(mockResponse)
	}))
	defer ts.Close()

	client := NewClient(ts.URL, "user", "pass")
	entry, err := client.GetNowPlaying()

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if entry == nil {
		t.Fatalf("expected valid entry, got nil")
	}

	if entry.SongID != "song1" {
		t.Errorf("expected songId 'song1', got %s", entry.SongID)
	}
	if entry.Title != "Test Title" {
		t.Errorf("expected title 'Test Title', got %s", entry.Title)
	}
	if entry.DurationSecs != 200 {
		t.Errorf("expected duration 200, got %d", entry.DurationSecs)
	}
}
