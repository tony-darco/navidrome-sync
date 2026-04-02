let _authParams: string | null = null;

async function getConfig() {
  if (_authParams) return;
  const res = await fetch('/api/config');
  const cfg = await res.json();
  _authParams = cfg.authParams;
}

function buildUrl(path: string, params?: Record<string, string>) {
  const sep = path.includes('?') ? '&' : '?';
  const extra = params
    ? '&' + new URLSearchParams(params).toString()
    : '';
  return `${path}${sep}${_authParams}${extra}`;
}

export interface Album {
  id: string;
  name: string;
  artist: string;
  coverArt: string;
  songCount: number;
  year?: number;
}

export interface Song {
  id: string;
  title: string;
  artist: string;
  album: string;
  albumId: string;
  coverArt: string;
  duration: number;
  track: number;
}

export async function init() {
  await getConfig();
}

export async function getAlbums(
  type: string = 'newest',
  size: number = 50,
  offset: number = 0,
): Promise<Album[]> {
  await getConfig();
  const url = buildUrl('/rest/getAlbumList2.view', {
    type,
    size: String(size),
    offset: String(offset),
  });
  const res = await fetch(url);
  const data = await res.json();
  const list = data?.['subsonic-response']?.albumList2?.album;
  return (list ?? []).map(mapAlbum);
}

export async function getAlbum(id: string): Promise<{ album: Album; songs: Song[] }> {
  await getConfig();
  const url = buildUrl('/rest/getAlbum.view', { id });
  const res = await fetch(url);
  const data = await res.json();
  const raw = data?.['subsonic-response']?.album;
  return {
    album: mapAlbum(raw),
    songs: (raw?.song ?? []).map(mapSong),
  };
}

export async function search(query: string): Promise<{ albums: Album[]; songs: Song[] }> {
  await getConfig();
  const url = buildUrl('/rest/search3.view', { query, albumCount: '20', songCount: '20' });
  const res = await fetch(url);
  const data = await res.json();
  const result = data?.['subsonic-response']?.searchResult3;
  return {
    albums: (result?.album ?? []).map(mapAlbum),
    songs: (result?.song ?? []).map(mapSong),
  };
}

export function streamUrl(songId: string): string {
  return buildUrl('/rest/stream.view', { id: songId });
}

export function getCoverArtUrl(id: string, size: number = 300): string {
  return buildUrl('/rest/getCoverArt.view', { id, size: String(size) });
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapAlbum(raw: any): Album {
  return {
    id: raw.id,
    name: raw.name ?? raw.title,
    artist: raw.artist ?? raw.albumArtist ?? '',
    coverArt: raw.coverArt ?? '',
    songCount: raw.songCount ?? 0,
    year: raw.year,
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapSong(raw: any): Song {
  return {
    id: raw.id,
    title: raw.title,
    artist: raw.artist ?? '',
    album: raw.album ?? '',
    albumId: raw.albumId ?? '',
    coverArt: raw.coverArt ?? '',
    duration: raw.duration ?? 0,
    track: raw.track ?? 0,
  };
}
