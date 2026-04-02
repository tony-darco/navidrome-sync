package config

import (
	"os"
	"strconv"
)

type Config struct {
	NavidromeURL  string
	Username      string
	Password      string
	PollInterval  int // seconds
	Port          int
}

func Load() Config {
	return Config{
		NavidromeURL: envOrDefault("NAVIDROME_URL", "http://localhost:4533"),
		Username:     envOrDefault("NAVIDROME_USER", ""),
		Password:     envOrDefault("NAVIDROME_PASSWORD", ""),
		PollInterval: envOrDefaultInt("POLL_INTERVAL_SECS", 3),
		Port:         envOrDefaultInt("PORT", 8080),
	}
}

func envOrDefault(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func envOrDefaultInt(key string, fallback int) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return n
}
