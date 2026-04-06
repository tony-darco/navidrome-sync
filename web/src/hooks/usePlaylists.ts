import { useCallback, useEffect, useState } from 'react';
import { getPlaylists } from '../api/navidrome';
import type { Playlist } from '../api/navidrome';
import { useSyncStore } from '../store/syncStore';

export function usePlaylists() {
  const [playlists, setPlaylists] = useState<Playlist[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const lastPlaylistInvalidation = useSyncStore((s) => s.lastPlaylistInvalidation);

  const refetch = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getPlaylists();
      setPlaylists(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load playlists');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refetch();
  }, [refetch]);

  useEffect(() => {
    if (lastPlaylistInvalidation) {
      refetch();
    }
  }, [lastPlaylistInvalidation, refetch]);

  return { playlists, loading, error, refetch };
}
