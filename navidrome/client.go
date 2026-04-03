package navidrome

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

type NowPlayingEntry struct {
	SongID       string `json:"songId"`
	Title        string `json:"title"`
	Artist       string `json:"artist"`
	Album        string `json:"album"`
	CoverArtID   string `json:"coverArtId"`
	DurationSecs int    `json:"durationSecs"`
}

type Client struct {
	baseURL  string
	user     string
	password string
	http     *http.Client
}

func NewClient(baseURL, user, password string) *Client {
	return &Client{
		baseURL:  baseURL,
		user:     user,
		password: password,
		http:     &http.Client{Timeout: 10 * time.Second},
	}
}

// subsonicResponse mirrors the minimal JSON structure returned by the Subsonic API.
type subsonicResponse struct {
	SubsonicResponse struct {
		Status string `json:"status"`
		Error  struct {
			Code    int    `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
		NowPlaying struct {
			Entry []struct {
				ID       string `json:"id"`
				Title    string `json:"title"`
				Artist   string `json:"artist"`
				Album    string `json:"album"`
				CoverArt string `json:"coverArt"`
				Duration int    `json:"duration"`
			} `json:"entry"`
		} `json:"nowPlaying"`
	} `json:"subsonic-response"`
}

// GetNowPlaying calls getNowPlaying.view and returns the first playing entry,
// or nil if nothing is currently playing.
func (c *Client) GetNowPlaying() (*NowPlayingEntry, error) {
	params := url.Values{
		"u": {c.user},
		"p": {c.password},
		"v": {"1.16.1"},
		"c": {"navidrome-sync"},
		"f": {"json"},
	}

	reqURL := fmt.Sprintf("%s/rest/getNowPlaying.view?%s", c.baseURL, params.Encode())
	resp, err := c.http.Get(reqURL)
	if err != nil {
		return nil, fmt.Errorf("navidrome request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("navidrome returned status %d", resp.StatusCode)
	}

	var sr subsonicResponse
	if err := json.NewDecoder(resp.Body).Decode(&sr); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	if sr.SubsonicResponse.Status != "ok" {
		return nil, fmt.Errorf("subsonic API error: status=%s code=%d message=%s",
			sr.SubsonicResponse.Status,
			sr.SubsonicResponse.Error.Code,
			sr.SubsonicResponse.Error.Message)
	}

	entries := sr.SubsonicResponse.NowPlaying.Entry
	if len(entries) == 0 {
		return nil, nil
	}

	e := entries[0]
	return &NowPlayingEntry{
		SongID:       e.ID,
		Title:        e.Title,
		Artist:       e.Artist,
		Album:        e.Album,
		CoverArtID:   e.CoverArt,
		DurationSecs: e.Duration,
	}, nil
}
