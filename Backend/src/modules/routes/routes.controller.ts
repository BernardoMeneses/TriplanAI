import { Router, Request, Response } from 'express';
import { routesService } from './routes.service';

const router = Router();

// POST /api/routes/calculate - Calcular rota entre dois pontos
router.post('/calculate', async (req: Request, res: Response) => {
  try {
    const { origin, destination, travelMode, waypoints, optimize } = req.body;
    
    if (!origin || !destination) {
      return res.status(400).json({ error: 'Origem e destino são obrigatórios' });
    }

    const route = await routesService.calculateRoute(origin, destination, travelMode, waypoints, optimize);
    if (!route) {
      return res.status(400).json({ error: 'Não foi possível calcular a rota' });
    }
    res.json(route);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao calcular rota' });
  }
});

// POST /api/routes/optimize - Calcular rota otimizada com múltiplos waypoints
router.post('/optimize', async (req: Request, res: Response) => {
  try {
    const { origin, destination, waypoints, travelMode } = req.body;
    
    if (!origin || !destination || !waypoints || !Array.isArray(waypoints)) {
      return res.status(400).json({ error: 'Origem, destino e waypoints são obrigatórios' });
    }

    const result = await routesService.getOptimizedRoute(origin, destination, waypoints, travelMode);
    if (!result) {
      return res.status(400).json({ error: 'Não foi possível otimizar a rota' });
    }
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao otimizar rota' });
  }
});

// POST /api/routes/alternatives - Obter rotas alternativas
router.post('/alternatives', async (req: Request, res: Response) => {
  try {
    const { origin, destination, travelMode } = req.body;
    
    if (!origin || !destination) {
      return res.status(400).json({ error: 'Origem e destino são obrigatórios' });
    }

    const routes = await routesService.getAlternativeRoutes(origin, destination, travelMode);
    res.json(routes);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao obter rotas alternativas' });
  }
});

// POST /api/routes/distance-matrix - Calcular matriz de distâncias
router.post('/distance-matrix', async (req: Request, res: Response) => {
  try {
    const { origins, destinations, travelMode } = req.body;
    
    if (!origins || !destinations || !Array.isArray(origins) || !Array.isArray(destinations)) {
      return res.status(400).json({ error: 'Origins e destinations são obrigatórios (arrays)' });
    }

    const matrix = await routesService.getDistanceMatrix(origins, destinations, travelMode);
    res.json(matrix);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao calcular matriz de distâncias' });
  }
});

// POST /api/routes/traffic - Obter tempo de viagem com tráfego
router.post('/traffic', async (req: Request, res: Response) => {
  try {
    const { origin, destination, departureTime } = req.body;
    
    if (!origin || !destination) {
      return res.status(400).json({ error: 'Origem e destino são obrigatórios' });
    }

    const departure = departureTime ? new Date(departureTime) : undefined;
    const result = await routesService.getTravelTimeWithTraffic(origin, destination, departure);
    
    if (!result) {
      return res.status(400).json({ error: 'Não foi possível calcular tempo com tráfego' });
    }
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao obter tempo com tráfego' });
  }
});

// POST /api/routes/decode-polyline - Descodificar polyline
router.post('/decode-polyline', async (req: Request, res: Response) => {
  try {
    const { polyline } = req.body;
    
    if (!polyline || typeof polyline !== 'string') {
      return res.status(400).json({ error: 'Polyline é obrigatória' });
    }

    const points = routesService.decodePolyline(polyline);
    res.json({ points });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao descodificar polyline' });
  }
});

// POST /api/routes/multi-segment - Calcular rotas com múltiplos segmentos usando transport_mode específico por segmento
router.post('/multi-segment', async (req: Request, res: Response) => {
  try {
    const { points } = req.body;
    
    if (!points || !Array.isArray(points) || points.length < 2) {
      return res.status(400).json({ error: 'Pontos são obrigatórios (mínimo 2 pontos)' });
    }

    const routes: any[] = [];
    
    // Calculate route for each segment
    for (let i = 0; i < points.length - 1; i++) {
      const origin = points[i];
      const destination = points[i + 1];
      const transportMode = destination.transportMode || 'walking';
      
      try {
        const routeResult = await routesService.calculateRoute(
          { lat: origin.lat, lng: origin.lng },
          { lat: destination.lat, lng: destination.lng },
          transportMode,
          []
        );
        
        if (routeResult) {
          routes.push({
            segmentIndex: i + 1, // Index of the destination point
            origin: { name: origin.name, lat: origin.lat, lng: origin.lng },
            destination: { name: destination.name, lat: destination.lat, lng: destination.lng },
            mode: transportMode,
            distance: routeResult.distance,
            duration: routeResult.duration,
            polyline: routeResult.polyline ? { points: routeResult.polyline } : null,
            steps: routeResult.steps || [],
          });
        }
      } catch (error) {
        console.error(`Error calculating route segment ${i}:`, error);
        // Continue with next segment even if this one fails
      }
    }
    
    res.json({ routes });
  } catch (error) {
    console.error('Error calculating multi-segment routes:', error);
    res.status(500).json({ error: 'Erro ao calcular rotas multi-segmento' });
  }
});

export const routesController = router;
