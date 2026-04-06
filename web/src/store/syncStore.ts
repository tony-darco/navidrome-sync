import { create } from 'zustand';
import { streamUrl } from '../api/navidrome';

export interface NowPlayingSong {
  songId: string;
  title: string;
  artist: string;
  album: string;
  coverArtId: string;
  durationSecs: number;
  positionSecs: number;
  isPlaying?: boolean;
}

export interface ConnectedClient {
  clientId: string;
  clientType: 'web' | 'ios';
  role: 'active' | 'observer';
}

// Persistent audio element — lives for the lifetime of the app.
const audio = new Audio();

export type RepeatMode = 'off' | 'all' | 'one';

interface SyncState {
  nowPlaying: NowPlayingSong | null;
  myClientId: string;
  myRole: 'active' | 'observer';
  activeClientId: string | null;
  connectedClients: ConnectedClient[];
  isConnected: boolean;
  lastSyncTime: number;

  // Playback state driven by the persistent <audio> element
  isPlaying: boolean;
  position: number;

  // Queue
  queue: NowPlayingSong[];
  queueIndex: number;

  // Shuffle & Repeat
  shuffle: boolean;
  repeatMode: RepeatMode;

  // WebSocket send function, set by useWebSocket
  sendMessage: ((type: string, payload?: Record<string, unknown>) => void) | null;
  setSendMessage: (fn: (type: string, payload?: Record<string, unknown>) => void) => void;

  setConnected: (connected: boolean) => void;
  setMyClientId: (id: string) => void;
  handleStateSync: (payload: {
    activeClientId: string | null;
    song: NowPlayingSong | null;
    clients: ConnectedClient[];
    queue?: NowPlayingSong[];
    queueIndex?: number;
    shuffle?: boolean;
    repeatMode?: RepeatMode;
  }) => void;
  handleRoleChange: (payload: { clientId: string; role: 'active' | 'observer' }) => void;
  handleCommand: (payload: { action: string; positionSecs?: number; song?: NowPlayingSong; queue?: NowPlayingSong[]; startIndex?: number; queueIndex?: number }) => void;
  handleError: (payload: { code: string; message: string }) => void;

  /** Get the underlying HTMLAudioElement (for direct binding in AudioManager). */
  getAudio: () => HTMLAudioElement;

  /** Load a song into the persistent audio and start playback. */
  playSong: (song: NowPlayingSong, isCommand?: boolean) => void;
  /** Set the queue and start playing a specific index. */
  playQueue: (queue: NowPlayingSong[], startIndex: number, isCommand?: boolean) => void;
  play: () => void;
  pause: () => void;
  seek: (positionSecs: number) => void;
  next: (isCommand?: boolean) => void;
  prev: (isCommand?: boolean) => void;

  toggleShuffle: () => void;
  cycleRepeatMode: () => void;
  removeFromQueue: (index: number) => void;
  playQueueIndex: (index: number, isCommand?: boolean) => void;
  clearQueue: () => void;
  showQueue: boolean;
  setShowQueue: (show: boolean) => void;

  // Playlist invalidation
  lastPlaylistInvalidation: { playlistId: string; action: string } | null;
  notifyPlaylistChanged: (playlistId: string, action: string) => void;

  claim: () => void;
  sendCommand: (type: 'PLAY' | 'PAUSE' | 'NEXT' | 'PREV' | 'SEEK' | 'PLAY_SONG' | 'LOAD_QUEUE' | 'PLAY_INDEX', payload?: Record<string, unknown>) => void;
  sendNowPlaying: (song: NowPlayingSong) => void;
  sendPositionUpdate: (positionSecs: number) => void;
  sendQueue: (queue: NowPlayingSong[], queueIndex: number) => void;
  sendPlaybackOptions: () => void;
}

function generateClientId(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  // Fallback for non-secure contexts (plain HTTP)
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}

export const useSyncStore = create<SyncState>((set, get) => ({
  nowPlaying: null,
  myClientId: generateClientId(),
  myRole: 'observer',
  activeClientId: null,
  connectedClients: [],
  isConnected: false,
  lastSyncTime: 0,
  isPlaying: false,
  position: 0,
  queue: [],
  queueIndex: 0,
  shuffle: false,
  repeatMode: 'off' as RepeatMode,
  showQueue: false,
  sendMessage: null,
  lastPlaylistInvalidation: null,

  setSendMessage: (fn) => set({ sendMessage: fn }),

  setConnected: (connected) => set({ isConnected: connected }),

  setMyClientId: (id) => set({ myClientId: id }),

  handleStateSync: (payload) => {
    const { myClientId, myRole: previousRole } = get();
    const myClient = payload.clients.find((c) => c.clientId === myClientId);
    const newRole = myClient?.role ?? 'observer';
    const justBecameActive = previousRole !== 'active' && newRole === 'active';
    
    const updates: Partial<SyncState> = {
      activeClientId: payload.activeClientId,
      connectedClients: payload.clients,
      myRole: newRole,
      lastSyncTime: Date.now(),
    };
    
    // Accept queue and state from server if we're an observer (or just became active via claim)
    if (newRole === 'observer' || justBecameActive) {
      updates.nowPlaying = payload.song;
      // Reflect the active client's actual play/pause state for observers.
      if (newRole === 'observer') {
        updates.isPlaying = payload.song?.isPlaying ?? false;
      }
      if (payload.queue) {
        updates.queue = payload.queue.map((q) => ({ ...q, positionSecs: 0 }));
        updates.queueIndex = payload.queueIndex ?? 0;
      }
      if (payload.shuffle != null) {
        updates.shuffle = payload.shuffle;
      }
      if (payload.repeatMode != null) {
        updates.repeatMode = payload.repeatMode;
      }
    }
    
    set(updates);

    // When we just became active and there's a song, load it.
    // Only auto-play if the hub says the song was actually playing.
    if (justBecameActive && payload.song) {
      const song = payload.song;
      const shouldPlay = song.isPlaying;
      if (!audio.paused && audio.src.includes(song.songId)) {
        if (Math.abs(audio.currentTime - song.positionSecs) > 2) {
          audio.currentTime = song.positionSecs;
        }
        if (!shouldPlay) {
          audio.pause();
        }
      } else {
        audio.src = streamUrl(song.songId);
        if (song.positionSecs > 0) {
          audio.currentTime = song.positionSecs;
        }
        if (shouldPlay) {
          audio.play().catch(() => {});
        }
      }
      set({ isPlaying: shouldPlay });
    }
  },

  handleRoleChange: (payload) => {
    const { myClientId } = get();
    if (payload.clientId === myClientId) {
      set({ myRole: payload.role });
    }
  },

  handleCommand: (payload) => {
    const store = get();
    switch (payload.action) {
      case 'STOP':
        audio.pause();
        audio.src = '';
        break;
      case 'PLAY':
        audio.play().catch(() => {});
        break;
      case 'PAUSE':
        audio.pause();
        break;
      case 'SEEK':
        if (payload.positionSecs != null) {
          audio.currentTime = payload.positionSecs;
        }
        break;
      case 'NEXT':
        store.next(true); // pass true to indicate it's an incoming command execution
        break;
      case 'PREV':
        store.prev(true);
        break;
      case 'PLAY_SONG':
        if (payload.song) {
          store.playSong(payload.song, true);
        }
        break;
      case 'LOAD_QUEUE':
        if (payload.queue && payload.startIndex !== undefined) {
          store.playQueue(payload.queue, payload.startIndex, true);
        }
        break;
      case 'PLAY_INDEX':
        if (payload.queueIndex !== undefined) {
          store.playQueueIndex(payload.queueIndex, true);
        }
        break;
    }
  },

  handleError: (payload) => {
    console.error(`[sync] ${payload.code}: ${payload.message}`);
  },

  getAudio: () => audio,

  playSong: (song, isCommand = false) => {
    const { myRole, sendNowPlaying, sendQueue } = get();
    if (myRole !== 'active' && !isCommand) {
      get().sendCommand('PLAY_SONG', { song });
      return;
    }
    set({ queue: [song], queueIndex: 0, nowPlaying: song });
    audio.src = streamUrl(song.songId);
    audio.play().catch(() => {});
    if (song.positionSecs > 0) {
      audio.currentTime = song.positionSecs;
    }
    sendQueue([song], 0);
    sendNowPlaying(song);
  },

  playQueue: (queue, startIndex, isCommand = false) => {
    const song = queue[startIndex];
    if (!song) return;
    const { myRole, sendNowPlaying, sendQueue } = get();
    if (myRole !== 'active' && !isCommand) {
      get().sendCommand('LOAD_QUEUE', { queue, startIndex });
      return;
    }
    set({ queue, queueIndex: startIndex, nowPlaying: song });
    audio.src = streamUrl(song.songId);
    audio.play().catch(() => {});
    sendQueue(queue, startIndex);
    sendNowPlaying(song);
  },

  play: () => {
    if (get().myRole !== 'active') {
      get().sendCommand('PLAY');
      return;
    }
    audio.play().catch(() => {});
    get().sendCommand('PLAY');
  },

  pause: () => {
    if (get().myRole !== 'active') {
      get().sendCommand('PAUSE');
      return;
    }
    audio.pause();
    get().sendCommand('PAUSE');
  },

  seek: (positionSecs) => {
    if (get().myRole !== 'active') {
      get().sendCommand('SEEK', { positionSecs });
      return;
    }
    audio.currentTime = positionSecs;
    get().sendCommand('SEEK', { positionSecs });
  },

  next: (isCommand = false) => {
    const { queue, queueIndex, sendNowPlaying, sendQueue, myRole, shuffle, repeatMode } = get();
    if (myRole !== 'active' && !isCommand) {
      get().sendCommand('NEXT');
      return;
    }
    if (queue.length === 0) return;

    // Repeat-one: replay the current track
    if (repeatMode === 'one') {
      audio.currentTime = 0;
      audio.play().catch(() => {});
      return;
    }

    let nextIndex: number;
    if (shuffle) {
      // Pick a random index different from current (if possible)
      if (queue.length === 1) {
        nextIndex = 0;
      } else {
        do {
          nextIndex = Math.floor(Math.random() * queue.length);
        } while (nextIndex === queueIndex);
      }
    } else {
      nextIndex = queueIndex + 1;
      if (nextIndex >= queue.length) {
        if (repeatMode === 'all') {
          nextIndex = 0;
        } else {
          return; // end of queue, no repeat
        }
      }
    }

    const song = queue[nextIndex];
    set({ queueIndex: nextIndex, nowPlaying: song });
    audio.src = streamUrl(song.songId);
    audio.play().catch(() => {});
    sendNowPlaying(song);
    sendQueue(queue, nextIndex);
  },

  prev: (isCommand = false) => {
    const { queue, queueIndex, sendNowPlaying, sendQueue, myRole, repeatMode } = get();
    if (myRole !== 'active' && !isCommand) {
      get().sendCommand('PREV');
      return;
    }
    // If more than 3s into the song, restart it; otherwise go to previous
    if (audio.currentTime > 3) {
      audio.currentTime = 0;
      return;
    }
    let prevIndex = queueIndex - 1;
    if (prevIndex < 0) {
      if (repeatMode === 'all') {
        prevIndex = queue.length - 1;
      } else {
        audio.currentTime = 0;
        return;
      }
    }
    const song = queue[prevIndex];
    set({ queueIndex: prevIndex, nowPlaying: song });
    audio.src = streamUrl(song.songId);
    audio.play().catch(() => {});
    sendNowPlaying(song);
    sendQueue(queue, prevIndex);
  },

  toggleShuffle: () => {
    set((s) => ({ shuffle: !s.shuffle }));
    // Defer so the state is updated before we read it
    setTimeout(() => get().sendPlaybackOptions(), 0);
  },

  cycleRepeatMode: () => {
    set((s) => {
      const modes: RepeatMode[] = ['off', 'all', 'one'];
      const idx = modes.indexOf(s.repeatMode);
      return { repeatMode: modes[(idx + 1) % modes.length] };
    });
    setTimeout(() => get().sendPlaybackOptions(), 0);
  },

  removeFromQueue: (index: number) => {
    const { queue, queueIndex, sendQueue } = get();
    if (index < 0 || index >= queue.length) return;
    const newQueue = [...queue];
    newQueue.splice(index, 1);
    let newIndex = queueIndex;
    if (index < queueIndex) {
      newIndex = queueIndex - 1;
    } else if (index === queueIndex && newIndex >= newQueue.length) {
      newIndex = Math.max(0, newQueue.length - 1);
    }
    set({ queue: newQueue, queueIndex: newIndex });
    sendQueue(newQueue, newIndex);
  },

  playQueueIndex: (index: number, isCommand = false) => {
    const { queue, sendNowPlaying, sendQueue, myRole } = get();
    if (index < 0 || index >= queue.length) return;
    const song = queue[index];
    if (myRole !== 'active' && !isCommand) {
      get().sendCommand('PLAY_INDEX', { queueIndex: index });
      return;
    }
    set({ queueIndex: index, nowPlaying: song });
    audio.src = streamUrl(song.songId);
    audio.play().catch(() => {});
    sendNowPlaying(song);
    sendQueue(queue, index);
  },

  clearQueue: () => {
    const { queueIndex, queue, sendQueue } = get();
    // Keep only the currently playing song
    const current = queue[queueIndex];
    if (current) {
      set({ queue: [current], queueIndex: 0 });
      sendQueue([current], 0);
    } else {
      set({ queue: [], queueIndex: 0 });
      sendQueue([], 0);
    }
  },

  setShowQueue: (show: boolean) => set({ showQueue: show }),

  notifyPlaylistChanged: (playlistId, action) => {
    get().sendMessage?.('PLAYLIST_CHANGED', { playlistId, action });
    set({ lastPlaylistInvalidation: { playlistId, action } });
  },

  claim: () => {
    get().sendMessage?.('CLAIM');
    // Start audio immediately inside the user gesture context so the browser
    // autoplay policy doesn't block the subsequent WebSocket-callback play().
    const { nowPlaying } = get();
    if (nowPlaying) {
      audio.src = streamUrl(nowPlaying.songId);
      if (nowPlaying.positionSecs > 0) {
        audio.currentTime = nowPlaying.positionSecs;
      }
      audio.play().catch(() => {});
    }
  },

  sendCommand: (type, payload) => {
    get().sendMessage?.(type, payload);
  },

  sendNowPlaying: (song) => {
    get().sendMessage?.('NOW_PLAYING', song as unknown as Record<string, unknown>);
  },

  sendPositionUpdate: (positionSecs) => {
    get().sendMessage?.('POSITION_UPDATE', { positionSecs });
  },

  sendQueue: (queue, queueIndex) => {
    const items = queue.map((s) => ({
      songId: s.songId,
      title: s.title,
      artist: s.artist,
      album: s.album,
      coverArtId: s.coverArtId,
      durationSecs: s.durationSecs,
    }));
    get().sendMessage?.('SET_QUEUE', { queue: items, queueIndex } as unknown as Record<string, unknown>);
  },

  sendPlaybackOptions: () => {
    const { shuffle, repeatMode } = get();
    get().sendMessage?.('SET_PLAYBACK_OPTIONS', { shuffle, repeatMode });
  },
}));

// Wire audio element events back into the store.
audio.addEventListener('play', () => useSyncStore.setState({ isPlaying: true }));
audio.addEventListener('pause', () => useSyncStore.setState({ isPlaying: false }));
audio.addEventListener('timeupdate', () => {
  useSyncStore.setState({ position: audio.currentTime });
});
audio.addEventListener('ended', () => {
  useSyncStore.getState().next();
});
