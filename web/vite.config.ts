import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    proxy: {
      '/ws': {
        target: 'http://localhost:8080',
        ws: true,
        configure: (proxy) => {
          const suppressEpipe = (err: Error) => {
            if ((err as NodeJS.ErrnoException).code === 'EPIPE') return;
            console.error('[ws proxy error]', err.message);
          };
          proxy.on('error', suppressEpipe as never);
          proxy.on('proxyReqWsError', suppressEpipe as never);
          // Suppress socket-level EPIPE errors on the server socket
          proxy.on('open', (proxySocket) => {
            proxySocket.on('error', suppressEpipe);
          });
        },
      },
      '/api': { target: 'http://localhost:8080' },
      '/rest': { target: 'http://localhost:8080' },
      '/nowplaying': { target: 'http://localhost:8080' },
    },
  },
  build: {
  outDir: 'dist',
  emptyOutDir: true,
 },
})
