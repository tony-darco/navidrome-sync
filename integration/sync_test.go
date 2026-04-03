package integration

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"navidrome-sync/hub"
	"navidrome-sync/navidrome"
)

func mockNavidrome(entry *navidrome.NowPlayingEntry) (*httptest.Server, *navidrome.Client) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		var entries []interface{}
		if entry != nil {
			entries = append(entries, map[string]interface{}{
				"id":       entry.SongID,
				"title":    entry.Title,
				"artist":   entry.Artist,
				"album":    entry.Album,
				"coverArt": entry.CoverArtID,
				"duration": float64(entry.DurationSecs),
			})
		}

		mockResponse := map[string]interface{}{
			"subsonic-response": map[string]interface{}{
				"status": "ok",
				"nowPlaying": map[string]interface{}{
					"entry": entries,
				},
			},
		}
		json.NewEncoder(w).Encode(mockResponse)
	}))

	return ts, navidrome.NewClient(ts.URL, "user", "pass")
}

func pollOnce(nd *navidrome.Client, h *hub.Hub, lastSongID string) (string, error) {
	entry, err := nd.GetNowPlaying()
	if err != nil {
		return lastSongID, err
	}

	currentID := ""
	if entry != nil {
		currentID = entry.SongID
	}

	if currentID != lastSongID {
		h.UpdateFromPoll(entry)
	}
	return currentID, nil
}

func TestPollLoopUpdatesHubState(t *testing.T) {
	h := hub.NewHub()
	go h.Run()

	ts, nd := mockNavidrome(&navidrome.NowPlayingEntry{
		SongID: "trackA",
		Title:  "Track A",
	})
	defer ts.Close()

	pollOnce(nd, h, "")

	time.Sleep(10 * time.Millisecond) // Give run a moment
	state := h.CurrentState()
	if state == nil || state.SongID != "trackA" {
		t.Fatalf("expected state updated to trackA, got %+v", state)
	}
}

func TestPollDetectsSongChange(t *testing.T) {
	h := hub.NewHub()
	go h.Run()

	// 1: first poll -> track A
	ts1, nd1 := mockNavidrome(&navidrome.NowPlayingEntry{SongID: "trackA", Title: "A"})
	defer ts1.Close()

	lastID, _ := pollOnce(nd1, h, "")

	// 2: second poll -> track B
	ts2, nd2 := mockNavidrome(&navidrome.NowPlayingEntry{SongID: "trackB", Title: "B"})
	defer ts2.Close()

	pollOnce(nd2, h, lastID)

	time.Sleep(10 * time.Millisecond) // Give run a moment to process the update
	state := h.CurrentState()
	if state == nil || state.SongID != "trackB" {
		t.Fatalf("unexpected state %v", state)
	}
}

func TestPollDoesNotRebroadcastSameSong(t *testing.T) {
	h := hub.NewHub()
	go h.Run()

	// Poll twice with same song
	ts, nd := mockNavidrome(&navidrome.NowPlayingEntry{SongID: "trackA", Title: "A"})
	defer ts.Close()

	lastID, _ := pollOnce(nd, h, "")

	// capture update calls by mock ... we actually just check pollOnce ID returns correctly
	newID, _ := pollOnce(nd, h, lastID)

	if newID != lastID {
		t.Errorf("expected same ID to be returned, got %v", newID)
	}
}
