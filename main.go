package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"time"

	"navidrome-sync/config"
	"navidrome-sync/hub"
	"navidrome-sync/navidrome"
)

func main() {
	cfg := config.Load()

	nd := navidrome.NewClient(cfg.NavidromeURL, cfg.Username, cfg.Password)
	h := hub.NewHub()
	go h.Run()

	// Poll Navidrome for now-playing changes.
	go pollLoop(nd, h, time.Duration(cfg.PollInterval)*time.Second)

	http.HandleFunc("/ws", h.HandleWS)
	http.HandleFunc("/nowplaying", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		state := h.CurrentState()
		json.NewEncoder(w).Encode(state)
	})
	http.HandleFunc("/api/config", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"authParams": fmt.Sprintf("u=%s&p=%s&v=1.16.1&c=navidrome-sync&f=json", cfg.Username, cfg.Password),
		})
	})

	// Reverse proxy for Navidrome Subsonic API — avoids CORS issues.
	ndURL, _ := url.Parse(cfg.NavidromeURL)
	ndProxy := httputil.NewSingleHostReverseProxy(ndURL)
	http.HandleFunc("/rest/", func(w http.ResponseWriter, r *http.Request) {
		r.Host = ndURL.Host
		ndProxy.ServeHTTP(w, r)
	})

	http.Handle("/", http.FileServer(http.Dir("./static")))

	addr := fmt.Sprintf(":%d", cfg.Port)
	log.Printf("navidrome-sync listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}

// pollLoop periodically fetches now-playing from Navidrome and updates the hub
// when the song changes.
func pollLoop(nd *navidrome.Client, h *hub.Hub, interval time.Duration) {
	var lastSongID string
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for range ticker.C {
		entry, err := nd.GetNowPlaying()
		if err != nil {
			log.Printf("poll error: %v", err)
			continue
		}

		currentID := ""
		if entry != nil {
			currentID = entry.SongID
		}

		if currentID != lastSongID {
			lastSongID = currentID
			h.UpdateFromPoll(entry)
			if entry != nil {
				log.Printf("now playing changed: %s — %s", entry.Artist, entry.Title)
			} else {
				log.Print("now playing cleared")
			}
		}
	}
}
