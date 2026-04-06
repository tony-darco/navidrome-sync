import { useEffect, useRef } from 'react';
import { useSyncStore } from '../store/syncStore';

const RECONNECT_DELAY = 2000;

export function useWebSocket() {
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const myClientId = useSyncStore((s) => s.myClientId);
  const setConnected = useSyncStore((s) => s.setConnected);
  const setSendMessage = useSyncStore((s) => s.setSendMessage);
  const handleStateSync = useSyncStore((s) => s.handleStateSync);
  const handleRoleChange = useSyncStore((s) => s.handleRoleChange);
  const handleCommand = useSyncStore((s) => s.handleCommand);
  const handleError = useSyncStore((s) => s.handleError);

  useEffect(() => {
    let isActive = true;

    function connect() {
      const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const ws = new WebSocket(`${proto}//${window.location.host}/ws?clientId=${myClientId}`);
      wsRef.current = ws;

      ws.addEventListener('open', () => {
        setConnected(true);
        // Send REGISTER immediately on connect
        const msg = JSON.stringify({
          type: 'REGISTER',
          clientId: myClientId,
          payload: { clientType: 'web' },
        });
        ws.send(msg);
      });

      ws.addEventListener('message', (event) => {
        try {
          const envelope = JSON.parse(event.data);
          switch (envelope.type) {
            case 'STATE_SYNC':
              handleStateSync(envelope.payload);
              break;
            case 'COMMAND':
              handleCommand(envelope.payload);
              break;
            case 'PLAYLIST_INVALIDATE':
              useSyncStore.setState({ lastPlaylistInvalidation: envelope.payload });
              break;
            case 'ERROR':
              handleError(envelope.payload);
              break;
          }
        } catch {
          console.error('[ws] failed to parse message', event.data);
        }
      });

      ws.addEventListener('close', () => {
        if (!isActive) return;
        setConnected(false);
        wsRef.current = null;
        reconnectTimer.current = setTimeout(connect, RECONNECT_DELAY);
      });

      ws.addEventListener('error', () => {
        ws.close();
      });
    }

    // Set up the sendMessage function
    const sendMessage = (type: string, payload?: Record<string, unknown>) => {
      const ws = wsRef.current;
      if (!ws || ws.readyState !== WebSocket.OPEN) return;
      ws.send(JSON.stringify({ type, clientId: myClientId, payload: payload ?? {} }));
    };
    setSendMessage(sendMessage);

    connect();

    return () => {
      isActive = false;
      clearTimeout(reconnectTimer.current);
      wsRef.current?.close();
      wsRef.current = null;
    };
  }, [myClientId, setConnected, setSendMessage, handleStateSync, handleRoleChange, handleCommand, handleError]);
}
