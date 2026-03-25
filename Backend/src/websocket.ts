import { Server } from 'ws';

let wss: Server | null = null;
const clientsByItinerary: Record<string, Set<any>> = {};

export function setupWebSocket(server: any) {
  wss = new Server({ server });

  wss.on('connection', (ws, req) => {
    // Espera-se que o cliente envie imediatamente o identificador do itinerário
    ws.on('message', (message: string) => {
      try {
        const data = JSON.parse(message);
        if (data.type === 'subscribe' && data.itineraryId && data.dayNumber) {
          const key = `${data.itineraryId}:${data.dayNumber}`;
          if (!clientsByItinerary[key]) clientsByItinerary[key] = new Set();
          clientsByItinerary[key].add(ws);
          ws.on('close', () => {
            clientsByItinerary[key].delete(ws);
          });
        }
      } catch {}
    });
  });
}

export function emitItineraryUpdate(itineraryId: string, dayNumber: number) {
  const key = `${itineraryId}:${dayNumber}`;
  const clients = clientsByItinerary[key];
  if (clients) {
    for (const ws of clients) {
      if (ws.readyState === 1) {
        ws.send(JSON.stringify({ type: 'itinerary_update', itineraryId, dayNumber }));
      }
    }
  }
}
