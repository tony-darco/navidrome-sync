import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockAudio } from '../../../vitest.setup';

// Must be declared before the import so Vitest hoists the mock above
// the module-level `streamUrl` call inside syncStore.
vi.mock('../../api/navidrome', () => ({
  streamUrl: (id: string) => `http://test/stream/${id}`,
  getConfig: vi.fn().mockResolvedValue(undefined),
}));

import { useSyncStore, type NowPlayingSong } from '../syncStore';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const song = (id: string): NowPlayingSong => ({
  songId: id,
  title: `Song ${id}`,
  artist: 'Test Artist',
  album: 'Test Album',
  coverArtId: `cover-${id}`,
  durationSecs: 200,
  positionSecs: 0,
});

const MY_ID = 'test-client-id';

/** Reset the store to a clean active state before each test. */
function resetActive() {
  useSyncStore.setState({
    myClientId: MY_ID,
    myRole: 'active',
    nowPlaying: null,
    queue: [],
    queueIndex: 0,
    sendMessage: vi.fn(),
    isPlaying: false,
    position: 0,
  });
  vi.clearAllMocks();
  mockAudio.src = '';
  mockAudio.currentTime = 0;
}

function resetObserver() {
  resetActive();
  useSyncStore.setState({ myRole: 'observer' });
}

// ---------------------------------------------------------------------------
// playSong
// ---------------------------------------------------------------------------

describe('playSong (active)', () => {
  beforeEach(resetActive);

  it('sets nowPlaying in the store', () => {
    useSyncStore.getState().playSong(song('a1'), true);
    expect(useSyncStore.getState().nowPlaying).toMatchObject({ songId: 'a1' });
  });

  it('sets queue to the single song', () => {
    useSyncStore.getState().playSong(song('a2'), true);
    expect(useSyncStore.getState().queue).toHaveLength(1);
    expect(useSyncStore.getState().queueIndex).toBe(0);
  });

  it('starts audio playback', () => {
    useSyncStore.getState().playSong(song('a3'), true);
    expect(mockAudio.src).toBe('http://test/stream/a3');
    expect(mockAudio.play).toHaveBeenCalled();
  });
});

describe('playSong (observer)', () => {
  beforeEach(resetObserver);

  it('sends PLAY_SONG command instead of playing locally', () => {
    const sendMessage = vi.fn();
    useSyncStore.setState({ sendMessage });
    useSyncStore.getState().playSong(song('obs1'));
    expect(sendMessage).toHaveBeenCalledWith('PLAY_SONG', expect.objectContaining({ song: expect.objectContaining({ songId: 'obs1' }) }));
    expect(mockAudio.play).not.toHaveBeenCalled();
  });

  it('does not mutate nowPlaying locally', () => {
    useSyncStore.setState({ sendMessage: vi.fn() });
    useSyncStore.getState().playSong(song('obs2'));
    expect(useSyncStore.getState().nowPlaying).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// playQueue
// ---------------------------------------------------------------------------

describe('playQueue (active)', () => {
  beforeEach(resetActive);

  it('sets nowPlaying to the song at startIndex', () => {
    const songs = [song('q1'), song('q2'), song('q3')];
    useSyncStore.getState().playQueue(songs, 1, true);
    expect(useSyncStore.getState().nowPlaying).toMatchObject({ songId: 'q2' });
  });

  it('sets queueIndex correctly', () => {
    const songs = [song('q1'), song('q2'), song('q3')];
    useSyncStore.getState().playQueue(songs, 2, true);
    expect(useSyncStore.getState().queueIndex).toBe(2);
    expect(useSyncStore.getState().queue).toHaveLength(3);
  });

  it('starts audio playback for the correct song', () => {
    const songs = [song('q1'), song('q2')];
    useSyncStore.getState().playQueue(songs, 1, true);
    expect(mockAudio.src).toBe('http://test/stream/q2');
    expect(mockAudio.play).toHaveBeenCalled();
  });
});

// ---------------------------------------------------------------------------
// next
// ---------------------------------------------------------------------------

describe('next (active)', () => {
  beforeEach(resetActive);

  it('advances queueIndex and updates nowPlaying', () => {
    const songs = [song('n1'), song('n2'), song('n3')];
    useSyncStore.setState({ queue: songs, queueIndex: 0, nowPlaying: songs[0] });
    useSyncStore.getState().next(true);
    expect(useSyncStore.getState().queueIndex).toBe(1);
    expect(useSyncStore.getState().nowPlaying).toMatchObject({ songId: 'n2' });
  });

  it('does nothing when at end of queue with repeat off', () => {
    const songs = [song('n1'), song('n2')];
    useSyncStore.setState({ queue: songs, queueIndex: 1, nowPlaying: songs[1], repeatMode: 'off' });
    useSyncStore.getState().next(true);
    expect(useSyncStore.getState().queueIndex).toBe(1);
  });

  it('wraps to start with repeat all', () => {
    const songs = [song('n1'), song('n2')];
    useSyncStore.setState({ queue: songs, queueIndex: 1, nowPlaying: songs[1], repeatMode: 'all' });
    useSyncStore.getState().next(true);
    expect(useSyncStore.getState().queueIndex).toBe(0);
    expect(useSyncStore.getState().nowPlaying).toMatchObject({ songId: 'n1' });
  });
});

// ---------------------------------------------------------------------------
// prev
// ---------------------------------------------------------------------------

describe('prev (active)', () => {
  beforeEach(resetActive);

  it('goes to previous track and updates nowPlaying', () => {
    const songs = [song('p1'), song('p2')];
    useSyncStore.setState({ queue: songs, queueIndex: 1, nowPlaying: songs[1] });
    mockAudio.currentTime = 0;
    useSyncStore.getState().prev(true);
    expect(useSyncStore.getState().queueIndex).toBe(0);
    expect(useSyncStore.getState().nowPlaying).toMatchObject({ songId: 'p1' });
  });

  it('restarts current track when more than 3s in', () => {
    const songs = [song('p1'), song('p2')];
    useSyncStore.setState({ queue: songs, queueIndex: 1, nowPlaying: songs[1] });
    mockAudio.currentTime = 10;
    useSyncStore.getState().prev(true);
    // queueIndex should be unchanged, audio seeks to 0
    expect(useSyncStore.getState().queueIndex).toBe(1);
    expect(mockAudio.currentTime).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// handleStateSync
// ---------------------------------------------------------------------------

describe('handleStateSync – active client', () => {
  beforeEach(resetActive);

  it('does NOT overwrite local nowPlaying with a server echo', () => {
    const localSong = song('local');
    useSyncStore.setState({ nowPlaying: localSong });

    useSyncStore.getState().handleStateSync({
      activeClientId: MY_ID,
      song: song('server-echo'),
      clients: [{ clientId: MY_ID, clientType: 'web', role: 'active' }],
    });

    expect(useSyncStore.getState().nowPlaying).toMatchObject({ songId: 'local' });
  });

  it('does NOT overwrite local queue with a server echo', () => {
    const localQueue = [song('l1'), song('l2')];
    useSyncStore.setState({ queue: localQueue, queueIndex: 0 });

    useSyncStore.getState().handleStateSync({
      activeClientId: MY_ID,
      song: song('s1'),
      clients: [{ clientId: MY_ID, clientType: 'web', role: 'active' }],
      queue: [song('server-q1')],
      queueIndex: 0,
    });

    expect(useSyncStore.getState().queue).toHaveLength(2);
  });
});

describe('handleStateSync – observer client', () => {
  beforeEach(resetObserver);

  it('accepts nowPlaying from server', () => {
    useSyncStore.getState().handleStateSync({
      activeClientId: 'other',
      song: song('from-server'),
      clients: [
        { clientId: MY_ID, clientType: 'web', role: 'observer' },
        { clientId: 'other', clientType: 'web', role: 'active' },
      ],
    });
    expect(useSyncStore.getState().nowPlaying).toMatchObject({ songId: 'from-server' });
  });

  it('accepts queue from server', () => {
    useSyncStore.getState().handleStateSync({
      activeClientId: 'other',
      song: song('s'),
      clients: [
        { clientId: MY_ID, clientType: 'web', role: 'observer' },
        { clientId: 'other', clientType: 'web', role: 'active' },
      ],
      queue: [song('s1'), song('s2'), song('s3')],
      queueIndex: 1,
    });
    expect(useSyncStore.getState().queue).toHaveLength(3);
    expect(useSyncStore.getState().queueIndex).toBe(1);
  });
});

describe('handleStateSync – claim (observer → active)', () => {
  beforeEach(resetObserver);

  it('accepts server nowPlaying when just becoming active', () => {
    const serverSong = song('claimed-song');
    useSyncStore.getState().handleStateSync({
      activeClientId: MY_ID,
      song: serverSong,
      clients: [{ clientId: MY_ID, clientType: 'web', role: 'active' }],
    });
    expect(useSyncStore.getState().nowPlaying).toMatchObject({ songId: 'claimed-song' });
  });
});
