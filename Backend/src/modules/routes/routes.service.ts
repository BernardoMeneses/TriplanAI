import { getDirectionsRoute } from '../../services/googleRoutesDirectionsApi.service';

const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY || '';

export interface Route {
  id: string;
  origin: Waypoint;
  destination: Waypoint;
  waypoints?: Waypoint[];
  distance: number; // em metros
  duration: number; // em segundos
  distanceText: string;
  durationText: string;
  polyline: string;
  steps: RouteStep[];
  travelMode: TravelModeType;
  bounds?: {
    northeast: { lat: number; lng: number };
    southwest: { lat: number; lng: number };
  };
  warnings?: string[];
  copyrights?: string;
}

export interface Waypoint {
  placeId?: string;
  name?: string;
  latitude: number;
  longitude: number;
}

export interface RouteStep {
  instruction: string;
  distance: number;
  distanceText: string;
  duration: number;
  durationText: string;
  startLocation: { lat: number; lng: number };
  endLocation: { lat: number; lng: number };
  travelMode: string;
  maneuver?: string;
}

export type TravelModeType = 'driving' | 'walking' | 'bicycling' | 'transit';

export interface DistanceMatrixResult {
  origin: Waypoint;
  destination: Waypoint;
  distance: number;
  distanceText: string;
  duration: number;
  durationText: string;
  status: string;
}



export class RoutesService {
  async calculateRoute(
    origin: Waypoint,
    destination: Waypoint,
    travelMode: TravelModeType = 'driving',
    waypoints?: Waypoint[],
    optimize?: boolean,
    language?: string
  ): Promise<Route | null> {
    try {
      // Nova API não suporta múltiplos waypoints ainda, só origem e destino
      const apiResponse = await getDirectionsRoute({
        origin: { lat: origin.latitude, lng: origin.longitude },
        destination: { lat: destination.latitude, lng: destination.longitude },
        travelMode,
        languageCode: 'pt-PT',
      });

      if (!apiResponse.routes || apiResponse.routes.length === 0) {
        return null;
      }
      const route = apiResponse.routes[0];
      const leg = route.legs && route.legs[0];

      // Calcular distância e duração totais
      const totalDistance = leg?.distanceMeters || 0;
      const totalDuration = leg?.duration ? (typeof leg.duration === 'string' ? this.parseDuration(leg.duration) : leg.duration) : 0;
      const allSteps: RouteStep[] = (leg?.steps || []).map((step: any) => ({
        instruction: step.navigationInstruction?.instructions || '',
        distance: step.distanceMeters || 0,
        distanceText: step.distanceMeters ? this.formatDistance(step.distanceMeters) : '',
        duration: step.duration ? (typeof step.duration === 'string' ? this.parseDuration(step.duration) : step.duration) : 0,
        durationText: step.duration ? this.formatDuration(typeof step.duration === 'string' ? this.parseDuration(step.duration) : step.duration) : '',
        startLocation: step.startLocation,
        endLocation: step.endLocation,
        travelMode: step.travelMode,
        maneuver: step.navigationInstruction?.maneuver,
      }));

      return {
        id: `route_${Date.now()}`,
        origin,
        destination,
        waypoints,
        distance: totalDistance,
        duration: totalDuration,
        distanceText: this.formatDistance(totalDistance),
        durationText: this.formatDuration(totalDuration),
        polyline: route.polyline?.encodedPolyline || '',
        steps: allSteps,
        travelMode,
        bounds: undefined, // Nova API não retorna bounds diretamente
        warnings: undefined,
        copyrights: undefined
      };
    } catch (error) {
      console.error('Erro ao calcular rota (Routes API):', error);
      return null;
    }
  }

  // getOptimizedRoute não suportado na nova API
  async getOptimizedRoute(): Promise<null> {
    throw new Error('getOptimizedRoute não suportado pela nova Google Routes API');
  }

  // getAlternativeRoutes não suportado na nova API
  async getAlternativeRoutes(): Promise<Route[]> {
    throw new Error('getAlternativeRoutes não suportado pela nova Google Routes API');
  }

  async getDistanceMatrix(
    origins: Waypoint[],
    destinations: Waypoint[],
    travelMode: TravelModeType = 'driving',
    language?: string
  ): Promise<DistanceMatrixResult[]> {
    try {
      const { getRouteMatrix } = await import('../../services/googleRoutesApi.service');
      const data = await getRouteMatrix(origins, destinations, travelMode);
      if (!Array.isArray(data)) {
        console.error('Resposta inesperada da Routes API:', data);
        return [];
      }
      const results: DistanceMatrixResult[] = data.map((item: any) => {
        // Considera status vazio/objeto como válido se houver distanceMeters
        let statusString = 'OK';
        if (typeof item.status === 'string') statusString = item.status;
        if (typeof item.status === 'object' && Object.keys(item.status).length > 0 && item.status.code) statusString = item.status.code;
        return {
          origin: origins[item.originIndex],
          destination: destinations[item.destinationIndex],
          distance: item.distanceMeters || 0,
          distanceText: item.distanceMeters ? this.formatDistance(item.distanceMeters) : 'N/A',
          duration: item.duration ? (typeof item.duration === 'string' ? this.parseDuration(item.duration) : item.duration.seconds) : 0,
          durationText: item.duration ? this.formatDuration(typeof item.duration === 'string' ? this.parseDuration(item.duration) : item.duration.seconds) : 'N/A',
          status: statusString,
        };
      });
      if (results.length === 0) {
        console.warn('⚠️ [getDistanceMatrix] Nenhum resultado retornado da nova Routes API');
      }
      return results;
    } catch (error: any) {
      console.error('Erro ao calcular matriz de distâncias (Routes API):', error?.response?.data || error);
      return [];
    }
  }

  // Utilitário para parsear string de duração tipo '3600s' para segundos
  private parseDuration(duration: string): number {
    if (!duration) return 0;
    const match = duration.match(/(\d+)s/);
    return match ? parseInt(match[1], 10) : 0;
  }

  // getTravelTimeWithTraffic não suportado na nova API
  async getTravelTimeWithTraffic(): Promise<null> {
    throw new Error('getTravelTimeWithTraffic não suportado pela nova Google Routes API');
  }

  decodePolyline(encoded: string): { lat: number; lng: number }[] {
    const points: { lat: number; lng: number }[] = [];
    let index = 0;
    let lat = 0;
    let lng = 0;

    while (index < encoded.length) {
      let shift = 0;
      let result = 0;
      let byte: number;

      do {
        byte = encoded.charCodeAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      const dlat = result & 1 ? ~(result >> 1) : result >> 1;
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        byte = encoded.charCodeAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      const dlng = result & 1 ? ~(result >> 1) : result >> 1;
      lng += dlng;

      points.push({
        lat: lat / 1e5,
        lng: lng / 1e5
      });
    }

    return points;
  }

  private formatDistance(meters: number): string {
    if (meters >= 1000) {
      return `${(meters / 1000).toFixed(1)} km`;
    }
    return `${meters} m`;
  }

  private formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    if (hours > 0) {
      return `${hours} h ${minutes} min`;
    }
    return `${minutes} min`;
  }

  /**
   * Get simple distance between two points (for itinerary items)
   */
  async getDistance(
    origin: { latitude: number; longitude: number },
    destination: { latitude: number; longitude: number },
    travelMode: TravelModeType = 'driving'
  ): Promise<{ distance: number; distanceText: string; duration: number; durationText: string } | null> {
    try {
      const originWaypoint: Waypoint = { latitude: origin.latitude, longitude: origin.longitude };
      const destWaypoint: Waypoint = { latitude: destination.latitude, longitude: destination.longitude };
      
      const results = await this.getDistanceMatrix([originWaypoint], [destWaypoint], travelMode);
      
      if (results.length > 0 && results[0].distance > 0) {
        return {
          distance: results[0].distance,
          distanceText: results[0].distanceText,
          duration: results[0].duration,
          durationText: results[0].durationText
        };
      }
      
      return null;
    } catch (error) {
      console.error('Error calculating distance:', error);
      return null;
    }
  }
}

export const routesService = new RoutesService();
