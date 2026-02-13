import { Client, TravelMode, UnitSystem, Language, DirectionsResponse } from '@googlemaps/google-maps-services-js';

const mapsClient = new Client({});
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

const mapTravelMode = (mode: TravelModeType): TravelMode => {
  const modes: Record<TravelModeType, TravelMode> = {
    driving: TravelMode.driving,
    walking: TravelMode.walking,
    bicycling: TravelMode.bicycling,
    transit: TravelMode.transit
  };
  return modes[mode] || TravelMode.driving;
};

const mapLanguage = (lang?: string): Language => {
  const languages: Record<string, Language> = {
    'en': Language.en,
    'pt': Language.pt_PT,
    'es': Language.es,
    'fr': Language.fr
  };
  return languages[lang || 'en'] || Language.en;
};

const waypointToString = (waypoint: Waypoint): string => {
  if (waypoint.placeId) {
    return `place_id:${waypoint.placeId}`;
  }
  return `${waypoint.latitude},${waypoint.longitude}`;
};

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
      const params: any = {
        origin: waypointToString(origin),
        destination: waypointToString(destination),
        mode: mapTravelMode(travelMode),
        key: GOOGLE_MAPS_API_KEY,
        language: mapLanguage(language),
        units: UnitSystem.metric
      };

      if (waypoints && waypoints.length > 0) {
        params.waypoints = waypoints.map(wp => waypointToString(wp));
        if (optimize) {
          params.optimize = true;
        }
      }

      const response = await mapsClient.directions({ params });

      if (response.data.routes.length === 0) {
        return null;
      }

      const route = response.data.routes[0];
      const leg = route.legs[0];

      // Calculate total distance and duration for multi-leg routes
      let totalDistance = 0;
      let totalDuration = 0;
      const allSteps: RouteStep[] = [];

      for (const routeLeg of route.legs) {
        totalDistance += routeLeg.distance.value;
        totalDuration += routeLeg.duration.value;

        for (const step of routeLeg.steps) {
          allSteps.push({
            instruction: step.html_instructions.replace(/<[^>]*>/g, ''),
            distance: step.distance.value,
            distanceText: step.distance.text,
            duration: step.duration.value,
            durationText: step.duration.text,
            startLocation: {
              lat: step.start_location.lat,
              lng: step.start_location.lng
            },
            endLocation: {
              lat: step.end_location.lat,
              lng: step.end_location.lng
            },
            travelMode: step.travel_mode,
            maneuver: step.maneuver
          });
        }
      }

      return {
        id: `route_${Date.now()}`,
        origin,
        destination,
        waypoints,
        distance: totalDistance,
        duration: totalDuration,
        distanceText: this.formatDistance(totalDistance),
        durationText: this.formatDuration(totalDuration),
        polyline: route.overview_polyline.points,
        steps: allSteps,
        travelMode,
        bounds: route.bounds ? {
          northeast: {
            lat: route.bounds.northeast.lat,
            lng: route.bounds.northeast.lng
          },
          southwest: {
            lat: route.bounds.southwest.lat,
            lng: route.bounds.southwest.lng
          }
        } : undefined,
        warnings: route.warnings,
        copyrights: route.copyrights
      };
    } catch (error) {
      console.error('Erro ao calcular rota:', error);
      return null;
    }
  }

  async getOptimizedRoute(
    origin: Waypoint,
    destination: Waypoint,
    waypoints: Waypoint[],
    travelMode: TravelModeType = 'driving',
    language?: string
  ): Promise<{ route: Route; waypointOrder: number[] } | null> {
    try {
      const params: any = {
        origin: waypointToString(origin),
        destination: waypointToString(destination),
        waypoints: waypoints.map(wp => waypointToString(wp)),
        optimize: true,
        mode: mapTravelMode(travelMode),
        key: GOOGLE_MAPS_API_KEY,
        language: mapLanguage(language),
        units: UnitSystem.metric
      };

      const response = await mapsClient.directions({ params });

      if (response.data.routes.length === 0) {
        return null;
      }

      const googleRoute = response.data.routes[0];
      const waypointOrder = googleRoute.waypoint_order || [];

      // Reorder waypoints according to optimized order
      const optimizedWaypoints = waypointOrder.map(index => waypoints[index]);

      // Calculate totals
      let totalDistance = 0;
      let totalDuration = 0;
      const allSteps: RouteStep[] = [];

      for (const leg of googleRoute.legs) {
        totalDistance += leg.distance.value;
        totalDuration += leg.duration.value;

        for (const step of leg.steps) {
          allSteps.push({
            instruction: step.html_instructions.replace(/<[^>]*>/g, ''),
            distance: step.distance.value,
            distanceText: step.distance.text,
            duration: step.duration.value,
            durationText: step.duration.text,
            startLocation: {
              lat: step.start_location.lat,
              lng: step.start_location.lng
            },
            endLocation: {
              lat: step.end_location.lat,
              lng: step.end_location.lng
            },
            travelMode: step.travel_mode,
            maneuver: step.maneuver
          });
        }
      }

      const route: Route = {
        id: `route_opt_${Date.now()}`,
        origin,
        destination,
        waypoints: optimizedWaypoints,
        distance: totalDistance,
        duration: totalDuration,
        distanceText: this.formatDistance(totalDistance),
        durationText: this.formatDuration(totalDuration),
        polyline: googleRoute.overview_polyline.points,
        steps: allSteps,
        travelMode,
        bounds: googleRoute.bounds ? {
          northeast: {
            lat: googleRoute.bounds.northeast.lat,
            lng: googleRoute.bounds.northeast.lng
          },
          southwest: {
            lat: googleRoute.bounds.southwest.lat,
            lng: googleRoute.bounds.southwest.lng
          }
        } : undefined,
        warnings: googleRoute.warnings,
        copyrights: googleRoute.copyrights
      };

      return { route, waypointOrder };
    } catch (error) {
      console.error('Erro ao otimizar rota:', error);
      return null;
    }
  }

  async getAlternativeRoutes(
    origin: Waypoint,
    destination: Waypoint,
    travelMode: TravelModeType = 'driving',
    language?: string
  ): Promise<Route[]> {
    try {
      const response = await mapsClient.directions({
        params: {
          origin: waypointToString(origin),
          destination: waypointToString(destination),
          mode: mapTravelMode(travelMode),
          alternatives: true,
          key: GOOGLE_MAPS_API_KEY,
          language: mapLanguage(language),
          units: UnitSystem.metric
        }
      });

      return response.data.routes.map((googleRoute, index) => {
        let totalDistance = 0;
        let totalDuration = 0;
        const allSteps: RouteStep[] = [];

        for (const leg of googleRoute.legs) {
          totalDistance += leg.distance.value;
          totalDuration += leg.duration.value;

          for (const step of leg.steps) {
            allSteps.push({
              instruction: step.html_instructions.replace(/<[^>]*>/g, ''),
              distance: step.distance.value,
              distanceText: step.distance.text,
              duration: step.duration.value,
              durationText: step.duration.text,
              startLocation: {
                lat: step.start_location.lat,
                lng: step.start_location.lng
              },
              endLocation: {
                lat: step.end_location.lat,
                lng: step.end_location.lng
              },
              travelMode: step.travel_mode,
              maneuver: step.maneuver
            });
          }
        }

        return {
          id: `route_alt_${Date.now()}_${index}`,
          origin,
          destination,
          distance: totalDistance,
          duration: totalDuration,
          distanceText: this.formatDistance(totalDistance),
          durationText: this.formatDuration(totalDuration),
          polyline: googleRoute.overview_polyline.points,
          steps: allSteps,
          travelMode,
          bounds: googleRoute.bounds ? {
            northeast: {
              lat: googleRoute.bounds.northeast.lat,
              lng: googleRoute.bounds.northeast.lng
            },
            southwest: {
              lat: googleRoute.bounds.southwest.lat,
              lng: googleRoute.bounds.southwest.lng
            }
          } : undefined,
          warnings: googleRoute.warnings,
          copyrights: googleRoute.copyrights
        };
      });
    } catch (error) {
      console.error('Erro ao obter rotas alternativas:', error);
      return [];
    }
  }

  async getDistanceMatrix(
    origins: Waypoint[],
    destinations: Waypoint[],
    travelMode: TravelModeType = 'driving',
    language?: string
  ): Promise<DistanceMatrixResult[]> {
    try {
      const response = await mapsClient.distancematrix({
        params: {
          origins: origins.map(wp => waypointToString(wp)),
          destinations: destinations.map(wp => waypointToString(wp)),
          mode: mapTravelMode(travelMode),
          key: GOOGLE_MAPS_API_KEY,
          language: mapLanguage(language),
          units: UnitSystem.metric
        }
      });

      const results: DistanceMatrixResult[] = [];

      response.data.rows.forEach((row, originIndex) => {
        row.elements.forEach((element, destIndex) => {
          results.push({
            origin: origins[originIndex],
            destination: destinations[destIndex],
            distance: element.distance?.value || 0,
            distanceText: element.distance?.text || 'N/A',
            duration: element.duration?.value || 0,
            durationText: element.duration?.text || 'N/A',
            status: element.status
          });
        });
      });

      return results;
    } catch (error) {
      console.error('Erro ao calcular matriz de distâncias:', error);
      return [];
    }
  }

  async getTravelTimeWithTraffic(
    origin: Waypoint,
    destination: Waypoint,
    departureTime?: Date,
    language?: string
  ): Promise<{ duration: number; durationInTraffic: number; durationText: string; durationInTrafficText: string } | null> {
    try {
      const response = await mapsClient.directions({
        params: {
          origin: waypointToString(origin),
          destination: waypointToString(destination),
          mode: TravelMode.driving,
          departure_time: departureTime ? Math.floor(departureTime.getTime() / 1000) : 'now',
          key: GOOGLE_MAPS_API_KEY,
          language: mapLanguage(language),
          units: UnitSystem.metric
        }
      });

      if (response.data.routes.length === 0) {
        return null;
      }

      const leg = response.data.routes[0].legs[0];
      
      return {
        duration: leg.duration.value,
        durationInTraffic: leg.duration_in_traffic?.value || leg.duration.value,
        durationText: leg.duration.text,
        durationInTrafficText: leg.duration_in_traffic?.text || leg.duration.text
      };
    } catch (error) {
      console.error('Erro ao obter tempo com tráfego:', error);
      return null;
    }
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
      
      if (results.length > 0 && results[0].status === 'OK') {
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
