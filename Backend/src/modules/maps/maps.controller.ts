import { Router, Request, Response } from 'express';
import { mapsService } from './maps.service';

const router = Router();

// GET /api/maps/geocode - Converter endereço em coordenadas
router.get('/geocode', async (req: Request, res: Response) => {
  try {
    const { address } = req.query;
    if (!address || typeof address !== 'string') {
      return res.status(400).json({ error: 'Endereço é obrigatório' });
    }
    const result = await mapsService.geocode(address);
    if (!result) {
      return res.status(404).json({ error: 'Endereço não encontrado' });
    }
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao geocodificar endereço' });
  }
});

// GET /api/maps/reverse-geocode - Converter coordenadas em endereço
router.get('/reverse-geocode', async (req: Request, res: Response) => {
  try {
    const { lat, lng } = req.query;
    if (!lat || !lng) {
      return res.status(400).json({ error: 'Coordenadas (lat, lng) são obrigatórias' });
    }
    const address = await mapsService.reverseGeocode(Number(lat), Number(lng));
    if (!address) {
      return res.status(404).json({ error: 'Endereço não encontrado para estas coordenadas' });
    }
    res.json({ address });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao obter endereço' });
  }
});

// GET /api/maps/place/:placeId - Obter detalhes de um lugar
router.get('/place/:placeId', async (req: Request, res: Response) => {
  try {
    const { placeId } = req.params;
    const place = await mapsService.getPlaceDetails(placeId);
    if (!place) {
      return res.status(404).json({ error: 'Lugar não encontrado' });
    }
    res.json(place);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao obter detalhes do lugar' });
  }
});

// GET /api/maps/search - Pesquisar lugares
router.get('/search', async (req: Request, res: Response) => {
  try {
    const { query, lat, lng, radius } = req.query;
    if (!query || typeof query !== 'string') {
      return res.status(400).json({ error: 'Query de pesquisa é obrigatória' });
    }
    
    const location = lat && lng ? { lat: Number(lat), lng: Number(lng) } : undefined;
    const places = await mapsService.searchPlaces(query, location, radius ? Number(radius) : undefined);
    res.json(places);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao pesquisar lugares' });
  }
});

// GET /api/maps/nearby - Obter lugares próximos
router.get('/nearby', async (req: Request, res: Response) => {
  try {
    const { lat, lng, radius, type } = req.query;
    if (!lat || !lng) {
      return res.status(400).json({ error: 'Coordenadas (lat, lng) são obrigatórias' });
    }
    
    const places = await mapsService.getNearbyPlaces(
      Number(lat), 
      Number(lng), 
      radius ? Number(radius) : undefined,
      type as string | undefined
    );
    res.json(places);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao obter lugares próximos' });
  }
});

// GET /api/maps/destinations/search - Pesquisar destinos (cidades/países)
router.get('/destinations/search', async (req: Request, res: Response) => {
  try {
    const { query } = req.query;
    if (!query || typeof query !== 'string') {
      return res.status(400).json({ error: 'Query é obrigatória' });
    }
    
    const places = await mapsService.searchPlaces(query);
    const formattedResults = places.map(place => {
      // Extrair cidade e país dos componentes do endereço
      const addressComponents = place.formattedAddress.split(',').map(s => s.trim());
      let city = '';
      let country = '';
      
      if (place.types.includes('locality') || place.types.includes('administrative_area_level_1')) {
        city = place.name;
        country = addressComponents[addressComponents.length - 1] || '';
      } else if (place.types.includes('country')) {
        country = place.name;
        city = '';
      } else {
        city = addressComponents[0] || place.name;
        country = addressComponents[addressComponents.length - 1] || '';
      }
      
      return {
        placeId: place.placeId,
        name: place.name,
        subtitle: place.formattedAddress,
        description: place.formattedAddress,
        types: place.types,
        city,
        country,
      };
    });
    
    res.json(formattedResults);
  } catch (error) {
    console.error('Error searching destinations:', error);
    res.status(500).json({ error: 'Erro ao pesquisar destinos' });
  }
});

// GET /api/maps/destinations/:placeId - Obter detalhes de destino
router.get('/destinations/:placeId', async (req: Request, res: Response) => {
  try {
    const { placeId } = req.params;
    const place = await mapsService.getPlaceDetails(placeId);
    if (!place) {
      return res.status(404).json({ error: 'Destino não encontrado' });
    }
    
    // Selecionar foto aleatória se disponível
    let photoUrl = null;
    if (place.photos && place.photos.length > 0) {
      const randomIndex = Math.floor(Math.random() * place.photos.length);
      photoUrl = place.photos[randomIndex];
    }
    
    res.json({
      placeId: place.placeId,
      name: place.name,
      subtitle: place.formattedAddress,
      formattedAddress: place.formattedAddress,
      location: place.location,
      types: place.types,
      photoUrl,
    });
  } catch (error) {
    console.error('Error getting destination details:', error);
    res.status(500).json({ error: 'Erro ao obter detalhes do destino' });
  }
});

// GET /api/maps/autocomplete - Autocomplete de lugares
router.get('/autocomplete', async (req: Request, res: Response) => {
  try {
    const { input, sessionToken } = req.query;
    if (!input || typeof input !== 'string') {
      return res.status(400).json({ error: 'Input é obrigatório' });
    }
    
    const predictions = await mapsService.getPlaceAutocomplete(input, sessionToken as string | undefined);
    res.json(predictions);
  } catch (error) {
    res.status(500).json({ error: 'Erro no autocomplete' });
  }
});

// GET /api/maps/destinations/search - Pesquisar destinos (cidades, países, regiões)
router.get('/destinations/search', async (req: Request, res: Response) => {
  try {
    const { query } = req.query;
    if (!query || typeof query !== 'string') {
      return res.status(400).json({ error: 'Query é obrigatória' });
    }
    
    const destinations = await mapsService.searchDestinations(query);
    res.json(destinations);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao pesquisar destinos' });
  }
});

// GET /api/maps/destinations/:placeId - Obter detalhes de um destino com foto
router.get('/destinations/:placeId', async (req: Request, res: Response) => {
  try {
    const { placeId } = req.params;
    
    const destination = await mapsService.getDestinationDetails(placeId);
    if (!destination) {
      return res.status(404).json({ error: 'Destino não encontrado' });
    }
    res.json(destination);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao obter detalhes do destino' });
  }
});

// POST /api/maps/static - Gerar URL de mapa estático
router.post('/static', async (req: Request, res: Response) => {
  try {
    const { center, zoom, markers, polylines } = req.body;
    if (!center || zoom === undefined) {
      return res.status(400).json({ error: 'Center e zoom são obrigatórios' });
    }
    
    const url = await mapsService.getStaticMapUrl({
      center,
      zoom,
      markers: markers || [],
      polylines
    });
    res.json({ url });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao gerar mapa estático' });
  }
});

// GET /api/maps/timezone - Obter fuso horário de uma localização
router.get('/timezone', async (req: Request, res: Response) => {
  try {
    const { lat, lng } = req.query;
    if (!lat || !lng) {
      return res.status(400).json({ error: 'Coordenadas (lat, lng) são obrigatórias' });
    }
    
    const timezone = await mapsService.getTimezone(Number(lat), Number(lng));
    if (!timezone) {
      return res.status(404).json({ error: 'Fuso horário não encontrado' });
    }
    res.json(timezone);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao obter fuso horário' });
  }
});

// POST /api/maps/elevation - Obter elevação de um caminho
router.post('/elevation', async (req: Request, res: Response) => {
  try {
    const { path } = req.body;
    if (!path || !Array.isArray(path) || path.length === 0) {
      return res.status(400).json({ error: 'Path é obrigatório (array de coordenadas)' });
    }
    
    const elevations = await mapsService.getElevation(path);
    res.json({ elevations });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao obter elevação' });
  }
});

// POST /api/maps/distance - Calcular distância entre dois pontos
router.post('/distance', async (req: Request, res: Response) => {
  try {
    const { point1, point2 } = req.body;
    if (!point1 || !point2) {
      return res.status(400).json({ error: 'Dois pontos são obrigatórios' });
    }
    
    const distanceKm = mapsService.calculateDistance(point1, point2);
    res.json({ 
      distanceKm,
      distanceMeters: distanceKm * 1000,
      distanceMiles: distanceKm * 0.621371
    });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao calcular distância' });
  }
});

// POST /api/maps/directions - Obter direções entre dois pontos
router.post('/directions', async (req: Request, res: Response) => {
  try {
    const { origin, destination, waypoints, mode } = req.body;
    
    if (!origin || !destination) {
      return res.status(400).json({ error: 'Origin e destination são obrigatórios' });
    }
    
    const directions = await mapsService.getDirections({
      origin,
      destination,
      waypoints: waypoints || [],
      mode: mode || 'walking',
    });
    
    res.json(directions);
  } catch (error) {
    console.error('Error getting directions:', error);
    res.status(500).json({ error: 'Erro ao obter direções' });
  }
});

// POST /api/maps/route/optimized - Obter rota otimizada com múltiplos transportes
router.post('/route/optimized', async (req: Request, res: Response) => {
  try {
    const { points } = req.body;
    
    if (!points || !Array.isArray(points) || points.length < 2) {
      return res.status(400).json({ error: 'Pelo menos 2 pontos são necessários' });
    }
    
    const routes = await mapsService.getOptimizedRouteWithTransports(points);
    res.json(routes);
  } catch (error) {
    console.error('Error getting optimized route:', error);
    res.status(500).json({ error: 'Erro ao obter rota otimizada' });
  }
});

export const mapsController = router;
