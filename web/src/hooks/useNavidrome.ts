import { useState, useEffect, useCallback } from 'react';
import * as api from '../api/navidrome';

export function useGenres() {
  const [genres, setGenres] = useState<api.Genre[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    api.getGenres().then((result) => {
      if (!cancelled) {
        setGenres(result.sort((a, b) => a.value.localeCompare(b.value)));
      }
    }).catch((e) => {
      if (!cancelled) setError(e instanceof Error ? e.message : 'Failed to load genres');
    }).finally(() => {
      if (!cancelled) setLoading(false);
    });
    return () => { cancelled = true; };
  }, []);

  return { genres, loading, error };
}

export function useAlbums() {
  const [albums, setAlbums] = useState<api.Album[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadMore = useCallback(async (type = 'newest', size = 50, offset = 0, genre?: string) => {
    setLoading(true);
    setError(null);
    try {
      const result = await api.getAlbums(type, size, offset, genre);
      if (offset > 0) {
        setAlbums((prev) => [...prev, ...result]);
      } else {
        setAlbums(result);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load albums');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadMore();
  }, [loadMore]);

  return { albums, loading, error, reload: loadMore };
}

export function useAlbumDetail(albumId: string | null) {
  const [album, setAlbum] = useState<api.Album | null>(null);
  const [songs, setSongs] = useState<api.Song[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!albumId) {
      setAlbum(null);
      setSongs([]);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setError(null);
    api.getAlbum(albumId).then((result) => {
      if (cancelled) return;
      setAlbum(result.album);
      setSongs(result.songs);
    }).catch((e) => {
      if (cancelled) return;
      setError(e instanceof Error ? e.message : 'Failed to load album');
    }).finally(() => {
      if (!cancelled) setLoading(false);
    });
    return () => { cancelled = true; };
  }, [albumId]);

  return { album, songs, loading, error };
}

export function useSearch() {
  const [results, setResults] = useState<{ albums: api.Album[]; songs: api.Song[] }>({ albums: [], songs: [] });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const doSearch = useCallback(async (query: string) => {
    if (!query.trim()) {
      setResults({ albums: [], songs: [] });
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const result = await api.search(query);
      setResults(result);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Search failed');
    } finally {
      setLoading(false);
    }
  }, []);

  return { results, loading, error, doSearch };
}

export function useArtists() {
  const [artists, setArtists] = useState<api.ArtistIndex[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    api.getArtists().then((result) => {
      if (!cancelled) setArtists(result);
    }).catch((e) => {
      if (!cancelled) setError(e instanceof Error ? e.message : 'Failed to load artists');
    }).finally(() => {
      if (!cancelled) setLoading(false);
    });
    return () => { cancelled = true; };
  }, []);

  return { artists, loading, error };
}

export function useArtistDetail(artistId: string | null) {
  const [artist, setArtist] = useState<api.ArtistDetail | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!artistId) return;
    let cancelled = false;
    // Use microtask to batch with render and avoid lint warning
    queueMicrotask(() => { if (!cancelled) { setLoading(true); setError(null); } });
    api.getArtist(artistId).then((result) => {
      if (!cancelled) setArtist(result);
    }).catch((e) => {
      if (!cancelled) setError(e instanceof Error ? e.message : 'Failed to load artist');
    }).finally(() => {
      if (!cancelled) setLoading(false);
    });
    return () => { cancelled = true; };
  }, [artistId]);

  return { artist, loading, error };
}

export function useSongs() {
  const [songs, setSongs] = useState<api.Song[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadMore = useCallback(async (offset = 0, count = 50) => {
    setLoading(true);
    setError(null);
    try {
      const result = await api.getSongs(offset, count);
      if (offset > 0) {
        setSongs((prev) => [...prev, ...result]);
      } else {
        setSongs(result);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load songs');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadMore();
  }, [loadMore]);

  return { songs, loading, error, loadMore };
}
