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
  starred?: string;
}

export interface Song {
  id: string;
  title: string;
  artist: string;
  album: string;
  albumId: string;
  artistId: string;
  coverArt: string;
  duration: number;
  track: number;
  starred?: string;
}

export interface ArtistID3 {
  id: string;
  name: string;
  albumCount: number;
  coverArt?: string;
  artistImageUrl?: string;
}

export interface ArtistIndex {
  name: string;
  artist: ArtistID3[];
}

export interface ArtistDetail {
  id: string;
  name: string;
  coverArt?: string;
  artistImageUrl?: string;
  album: Album[];
}

export interface Playlist {
  id: string;
  name: string;
  songCount: number;
  coverArt: string;
}

export interface PlaylistWithSongs extends Playlist {
  entry: Song[];
}

export interface Genre {
  value: string;
  songCount: number;
  albumCount: number;
}

export async function init() {
  await getConfig();
}

export async function getAlbums(
  type: string = 'newest',
  size: number = 50,
  offset: number = 0,
  genre?: string,
): Promise<Album[]> {
  await getConfig();
  const params: Record<string, string> = {
    type,
    size: String(size),
    offset: String(offset),
  };
  if (genre) params.genre = genre;
  const url = buildUrl('/rest/getAlbumList2.view', params);
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

export async function getArtists(): Promise<ArtistIndex[]> {
  await getConfig();
  const url = buildUrl('/rest/getArtists.view');
  const res = await fetch(url);
  const data = await res.json();
  const indexes = data?.['subsonic-response']?.artists?.index;
  return (indexes ?? []).map(mapArtistIndex);
}

export async function getArtist(id: string): Promise<ArtistDetail> {
  await getConfig();
  const url = buildUrl('/rest/getArtist.view', { id });
  const res = await fetch(url);
  const data = await res.json();
  const raw = data?.['subsonic-response']?.artist;
  return {
    id: raw.id,
    name: raw.name ?? '',
    coverArt: raw.coverArt ?? undefined,
    artistImageUrl: raw.artistImageUrl ?? undefined,
    album: (raw?.album ?? []).map(mapAlbum),
  };
}

export interface ArtistInfo {
  largeImageUrl?: string;
  mediumImageUrl?: string;
  smallImageUrl?: string;
}

// In-memory cache for artist image URLs so we don't re-fetch constantly
const _artistImageCache = new Map<string, ArtistInfo>();

export async function getArtistInfo2(id: string): Promise<ArtistInfo> {
  const cached = _artistImageCache.get(id);
  if (cached) return cached;

  await getConfig();
  const url = buildUrl('/rest/getArtistInfo2.view', { id });
  const res = await fetch(url);
  const data = await res.json();
  const raw = data?.['subsonic-response']?.artistInfo2;
  const info: ArtistInfo = {
    largeImageUrl: raw?.largeImageUrl || undefined,
    mediumImageUrl: raw?.mediumImageUrl || undefined,
    smallImageUrl: raw?.smallImageUrl || undefined,
  };
  _artistImageCache.set(id, info);
  return info;
}

export async function getSongs(
  offset: number = 0,
  count: number = 50,
): Promise<Song[]> {
  await getConfig();
  const url = buildUrl('/rest/search3.view', {
    query: '',
    songCount: String(count),
    songOffset: String(offset),
    artistCount: '0',
    albumCount: '0',
  });
  const res = await fetch(url);
  const data = await res.json();
  const result = data?.['subsonic-response']?.searchResult3;
  return (result?.song ?? []).map(mapSong);
}

export async function getGenres(): Promise<Genre[]> {
  await getConfig();
  const url = buildUrl('/rest/getGenres.view');
  const res = await fetch(url);
  const data = await res.json();
  const list = data?.['subsonic-response']?.genres?.genre;
  return (list ?? []).map((g: any) => ({  // eslint-disable-line @typescript-eslint/no-explicit-any
    value: g.value ?? '',
    songCount: g.songCount ?? 0,
    albumCount: g.albumCount ?? 0,
  }));
}

export async function getSongsByGenre(
  genre: string,
  count: number = 50,
  offset: number = 0,
): Promise<Song[]> {
  await getConfig();
  const url = buildUrl('/rest/getSongsByGenre.view', {
    genre,
    count: String(count),
    offset: String(offset),
  });
  const res = await fetch(url);
  const data = await res.json();
  const list = data?.['subsonic-response']?.songsByGenre?.song;
  return (list ?? []).map(mapSong);
}

export async function getPlaylists(): Promise<Playlist[]> {
  await getConfig();
  const url = buildUrl('/rest/getPlaylists.view');
  const res = await fetch(url);
  const data = await res.json();
  const list = data?.['subsonic-response']?.playlists?.playlist;
  return (list ?? []).map(mapPlaylist);
}

export async function getPlaylist(id: string): Promise<PlaylistWithSongs> {
  await getConfig();
  const url = buildUrl('/rest/getPlaylist.view', { id });
  const res = await fetch(url);
  const data = await res.json();
  const raw = data?.['subsonic-response']?.playlist;
  return {
    ...mapPlaylist(raw),
    entry: (raw?.entry ?? []).map(mapSong),
  };
}

export async function createPlaylist(name: string, songIds?: string[]): Promise<string> {
  await getConfig();
  const params: Record<string, string> = { name };
  const url = buildUrl('/rest/createPlaylist.view', params);
  // songId params must be repeated, not comma-joined
  const songParams = songIds ? songIds.map((id) => `&songId=${encodeURIComponent(id)}`).join('') : '';
  const res = await fetch(url + songParams);
  const data = await res.json();
  return data?.['subsonic-response']?.playlist?.id ?? '';
}

export async function updatePlaylist(
  playlistId: string,
  songIdsToAdd: string[],
  songIndexesToRemove: number[],
): Promise<void> {
  await getConfig();
  const url = buildUrl('/rest/updatePlaylist.view', { playlistId });
  const addParams = songIdsToAdd.map((id) => `&songIdToAdd=${encodeURIComponent(id)}`).join('');
  const removeParams = songIndexesToRemove.map((i) => `&songIndexToRemove=${i}`).join('');
  await fetch(url + addParams + removeParams);
}

export async function deletePlaylist(id: string): Promise<void> {
  await getConfig();
  const url = buildUrl('/rest/deletePlaylist.view', { id });
  await fetch(url);
}

export async function star(id: string): Promise<void> {
  await getConfig();
  const url = buildUrl('/rest/star.view', { id });
  await fetch(url);
}

export async function unstar(id: string): Promise<void> {
  await getConfig();
  const url = buildUrl('/rest/unstar.view', { id });
  await fetch(url);
}

export async function scrobble(id: string): Promise<void> {
  await getConfig();
  const url = buildUrl('/rest/scrobble.view', { id });
  await fetch(url);
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
    starred: raw.starred,
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
    artistId: raw.artistId ?? '',
    coverArt: raw.coverArt ?? '',
    duration: raw.duration ?? 0,
    track: raw.track ?? 0,
    starred: raw.starred,
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapPlaylist(raw: any): Playlist {
  return {
    id: raw.id,
    name: raw.name ?? '',
    songCount: raw.songCount ?? 0,
    coverArt: raw.coverArt ?? '',
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapArtistIndex(raw: any): ArtistIndex {
  return {
    name: raw.name ?? '',
    artist: (raw.artist ?? []).map((a: any) => ({  // eslint-disable-line @typescript-eslint/no-explicit-any
      id: a.id,
      name: a.name ?? '',
      albumCount: a.albumCount ?? 0,
      coverArt: a.coverArt ?? undefined,
      artistImageUrl: a.artistImageUrl ?? undefined,
    })),
  };
}
