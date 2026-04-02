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
}

export interface ConnectedClient {
  clientId: string;
  clientType: 'web' | 'ios';
  role: 'active' | 'observer';
}

// Persistent audio element — lives for the lifetime of the app.
const audio = new Audio();

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

  // WebSocket send function, set by useWebSocket
  sendMessage: ((type: string, payload?: Record<string, unknown>) => void) | null;
  setSendMessage: (fn: (type: string, payload?: Record<string, unknown>) => void) => void;

  setConnected: (connected: boolean) => void;
  setMyClientId: (id: string) => void;
  handleStateSync: (payload: {
    activeClientId: string | null;
    song: NowPlayingSong | null;
    clients: ConnectedClient[];
  }) => void;
  handleRoleChange: (payload: { clientId: string; role: 'active' | 'observer' }) => void;
  handleError: (payload: { code: string; message: string }) => void;

  /** Get the underlying HTMLAudioElement (for direct binding in AudioManager). */
  getAudio: () => HTMLAudioElement;

  /** Load a song into the persistent audio and start playback. */
  playSong: (song: NowPlayingSong) => void;
  /** Set the queue and start playing a specific index. */
  playQueue: (queue: NowPlayingSong[], startIndex: number) => void;
  play: () => void;
  pause: () => void;
  seek: (positionSecs: number) => void;
  next: () => void;
  prev: () => void;

  claim: () => void;
  sendCommand: (type: 'PLAY' | 'PAUSE' | 'NEXT' | 'PREV' | 'SEEK', payload?: Record<string, unknown>) => void;
  sendNowPlaying: (song: NowPlayingSong) => void;
  sendPositionUpdate: (positionSecs: number) => void;
}

export const useSyncStore = create<SyncState>((set, get) => ({
  nowPlaying: null,
  myClientId: crypto.randomUUID(),
  myRole: 'observer',
  activeClientId: null,
  connectedClients: [],
  isConnected: false,
  lastSyncTime: 0,
  isPlaying: false,
  position: 0,
  queue: [],
  queueIndex: 0,
  sendMessage: null,

  setSendMessage: (fn) => set({ sendMessage: fn }),

  setConnected: (connected) => set({ isConnected: connected }),

  setMyClientId: (id) => set({ myClientId: id }),

  handleStateSync: (payload) => {
    const { myClientId } = get();
    const myClient = payload.clients.find((c) => c.clientId === myClientId);
    set({
      nowPlaying: payload.song,
      activeClientId: payload.activeClientId,
      connectedClients: payload.clients,
      myRole: myClient?.role ?? 'observer',
      lastSyncTime: Date.now(),
    });
  },

  handleRoleChange: (payload) => {
    const { myClientId } = get();
    if (payload.clientId === myClientId) {
      set({ myRole: payload.role });
    }
  },

  handleError: (payload) => {
    console.error(`[sync] ${payload.code}: ${payload.message}`);
  },

  getAudio: () => audio,

  playSong: (song) => {
    const { myRole, sendNowPlaying } = get();
    if (myRole !== 'active') {
      get().sendMessage?.('CLAIM');
    }
    set({ queue: [song], queueIndex: 0 });
    audio.src = streamUrl(song.songId);
    audio.play().catch(() => {});
    sendNowPlaying(song);
  },

  playQueue: (queue, startIndex) => {
    const song = queue[startIndex];
    if (!song) return;
    const { myRole, sendNowPlaying } = get();
    if (myRole !== 'active') {
      get().sendMessage?.('CLAIM');
    }
    set({ queue, queueIndex: startIndex });
    audio.src = streamUrl(song.songId);
    audio.play().catch(() => {});
    sendNowPlaying(song);
  },

  play: () => {
    audio.play().catch(() => {});
    get().sendCommand('PLAY');
  },

  pause: () => {
    audio.pause();
    get().sendCommand('PAUSE');
  },

  seek: (positionSecs) => {
    audio.currentTime = positionSecs;
    get().sendCommand('SEEK', { positionSecs });
  },

  next: () => {
    const { queue, queueIndex, sendNowPlaying, myRole } = get();
    const nextIndex = queueIndex + 1;
    if (nextIndex >= queue.length) return;
    const song = queue[nextIndex];
    if (myRole !== 'active') {
      get().sendMessage?.('CLAIM');
    }
    set({ queueIndex: nextIndex });
    audio.src = streamUrl(song.songId);
    audio.play().catch(() => {});
    sendNowPlaying(song);
  },

  prev: () => {
    const { queue, queueIndex, sendNowPlaying, myRole } = get();
    // If more than 3s into the song, restart it; otherwise go to previous
    if (audio.currentTime > 3) {
      audio.currentTime = 0;
      return;
    }
    const prevIndex = queueIndex - 1;
    if (prevIndex < 0) {
      audio.currentTime = 0;
      return;
    }
    const song = queue[prevIndex];
    if (myRole !== 'active') {
      get().sendMessage?.('CLAIM');
    }
    set({ queueIndex: prevIndex });
    audio.src = streamUrl(song.songId);
    audio.play().catch(() => {});
    sendNowPlaying(song);
  },

  claim: () => {
    get().sendMessage?.('CLAIM');
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
