import { Client, GeocodeResult, PlaceInputType, TravelMode, Language } from '@googlemaps/google-maps-services-js';

const mapsClient = new Client({});
const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY || '';

export interface MapConfig {
  center: { lat: number; lng: number };
  zoom: number;
  markers: MapMarker[];
  polylines?: MapPolyline[];
}

export interface MapMarker {
  id: string;
  position: { lat: number; lng: number };
  title?: string;
  icon?: string;
  info?: string;
}

export interface MapPolyline {
  id: string;
  path: { lat: number; lng: number }[];
  color?: string;
  weight?: number;
}

export interface GeocodingResult {
  lat: number;
  lng: number;
  formattedAddress: string;
  placeId: string;
  components: {
    city?: string;
    country?: string;
    postalCode?: string;
    street?: string;
    number?: string;
  };
}

export interface PlaceDetails {
  placeId: string;
  name: string;
  formattedAddress: string;
  location: { lat: number; lng: number };
  types: string[];
  rating?: number;
  priceLevel?: number;
  openingHours?: {
    weekdayText: string[];
    isOpenNow?: boolean;
  };
  photos?: string[];
  phoneNumber?: string;
  website?: string;
}

export class MapsService {
  async geocode(address: string): Promise<GeocodingResult | null> {
    try {
      const response = await mapsClient.geocode({
        params: {
          address,
          key: GOOGLE_MAPS_API_KEY,
          language: Language.pt_PT
        }
      });

      if (response.data.results.length === 0) {
        return null;
      }

      const result = response.data.results[0];
      const location = result.geometry.location;
      
      // Extract address components
      const components: GeocodingResult['components'] = {};
      for (const component of result.address_components) {
        const types = component.types as string[];
        if (types.includes('locality')) {
          components.city = component.long_name;
        }
        if (types.includes('country')) {
          components.country = component.long_name;
        }
        if (types.includes('postal_code')) {
          components.postalCode = component.long_name;
        }
        if (types.includes('route')) {
          components.street = component.long_name;
        }
        if (types.includes('street_number')) {
          components.number = component.long_name;
        }
      }

      return {
        lat: location.lat,
        lng: location.lng,
        formattedAddress: result.formatted_address,
        placeId: result.place_id,
        components
      };
    } catch (error) {
      console.error('Erro ao geocodificar:', error);
      return null;
    }
  }

  async reverseGeocode(lat: number, lng: number): Promise<string | null> {
    try {
      const response = await mapsClient.reverseGeocode({
        params: {
          latlng: { lat, lng },
          key: GOOGLE_MAPS_API_KEY,
          language: Language.pt_PT
        }
      });

      if (response.data.results.length === 0) {
        return null;
      }

      return response.data.results[0].formatted_address;
    } catch (error) {
      console.error('Erro na geocodificação reversa:', error);
      return null;
    }
  }

  async getPlaceDetails(placeId: string): Promise<PlaceDetails | null> {
    try {
      const response = await mapsClient.placeDetails({
        params: {
          place_id: placeId,
          key: GOOGLE_MAPS_API_KEY,
          language: Language.pt_PT,
          fields: [
            'place_id',
            'name',
            'formatted_address',
            'geometry',
            'types',
            'rating',
            'price_level',
            'opening_hours',
            'photos',
            'formatted_phone_number',
            'website'
          ]
        }
      });

      const place = response.data.result;
      if (!place) return null;

      return {
        placeId: place.place_id || placeId,
        name: place.name || '',
        formattedAddress: place.formatted_address || '',
        location: {
          lat: place.geometry?.location.lat || 0,
          lng: place.geometry?.location.lng || 0
        },
        types: place.types || [],
        rating: place.rating,
        priceLevel: place.price_level,
        openingHours: place.opening_hours ? {
          weekdayText: place.opening_hours.weekday_text || [],
          isOpenNow: place.opening_hours.open_now
        } : undefined,
        photos: place.photos?.slice(0, 5).map(photo => 
          `https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${photo.photo_reference}&key=${GOOGLE_MAPS_API_KEY}`
        ),
        phoneNumber: place.formatted_phone_number,
        website: place.website
      };
    } catch (error) {
      console.error('Erro ao obter detalhes do lugar:', error);
      return null;
    }
  }

  async searchPlaces(query: string, location?: { lat: number; lng: number }, radius?: number): Promise<PlaceDetails[]> {
    try {
      const params: any = {
        query,
        key: GOOGLE_MAPS_API_KEY,
        language: Language.pt_PT
      };

      if (location) {
        params.location = location;
        params.radius = radius || 5000; // Default 5km
      }

      const response = await mapsClient.textSearch({ params });

      return response.data.results.slice(0, 20).map(place => ({
        placeId: place.place_id || '',
        name: place.name || '',
        formattedAddress: place.formatted_address || '',
        location: {
          lat: place.geometry?.location.lat || 0,
          lng: place.geometry?.location.lng || 0
        },
        types: place.types || [],
        rating: place.rating,
        priceLevel: place.price_level,
        photos: place.photos?.slice(0, 3).map(photo => 
          `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${photo.photo_reference}&key=${GOOGLE_MAPS_API_KEY}`
        )
      }));
    } catch (error) {
      console.error('Erro ao pesquisar lugares:', error);
      return [];
    }
  }

  async getNearbyPlaces(
    lat: number, 
    lng: number, 
    radius: number = 1000, 
    type?: string
  ): Promise<PlaceDetails[]> {
    try {
      const params: any = {
        location: { lat, lng },
        radius,
        key: GOOGLE_MAPS_API_KEY,
        language: Language.pt_PT
      };

      if (type) {
        params.type = type;
      }

      const response = await mapsClient.placesNearby({ params });

      return response.data.results.slice(0, 20).map(place => ({
        placeId: place.place_id || '',
        name: place.name || '',
        formattedAddress: place.vicinity || '',
        location: {
          lat: place.geometry?.location.lat || 0,
          lng: place.geometry?.location.lng || 0
        },
        types: place.types || [],
        rating: place.rating,
        priceLevel: place.price_level,
        photos: place.photos?.slice(0, 3).map(photo => 
          `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${photo.photo_reference}&key=${GOOGLE_MAPS_API_KEY}`
        )
      }));
    } catch (error) {
      console.error('Erro ao obter lugares próximos:', error);
      return [];
    }
  }

  async getStaticMapUrl(config: MapConfig): Promise<string> {
    const baseUrl = 'https://maps.googleapis.com/maps/api/staticmap';
    const params = new URLSearchParams({
      center: `${config.center.lat},${config.center.lng}`,
      zoom: config.zoom.toString(),
      size: '600x400',
      maptype: 'roadmap',
      key: GOOGLE_MAPS_API_KEY
    });

    // Add markers
    config.markers.forEach(marker => {
      const markerParam = `color:red|label:${marker.title?.charAt(0) || 'P'}|${marker.position.lat},${marker.position.lng}`;
      params.append('markers', markerParam);
    });

    // Add polylines
    if (config.polylines) {
      config.polylines.forEach(polyline => {
        const path = polyline.path.map(p => `${p.lat},${p.lng}`).join('|');
        const polylineParam = `color:${polyline.color || '0x0000ff'}|weight:${polyline.weight || 3}|${path}`;
        params.append('path', polylineParam);
      });
    }

    return `${baseUrl}?${params.toString()}`;
  }

  async getElevation(path: { lat: number; lng: number }[]): Promise<number[]> {
    try {
      const response = await mapsClient.elevation({
        params: {
          locations: path,
          key: GOOGLE_MAPS_API_KEY
        }
      });

      return response.data.results.map(result => result.elevation);
    } catch (error) {
      console.error('Erro ao obter elevação:', error);
      return [];
    }
  }

  async getTimezone(lat: number, lng: number): Promise<{ timeZoneId: string; timeZoneName: string; rawOffset: number; dstOffset: number } | null> {
    try {
      const response = await mapsClient.timezone({
        params: {
          location: { lat, lng },
          timestamp: Math.floor(Date.now() / 1000),
          key: GOOGLE_MAPS_API_KEY
        }
      });

      const data = response.data;
      return {
        timeZoneId: data.timeZoneId,
        timeZoneName: data.timeZoneName,
        rawOffset: data.rawOffset,
        dstOffset: data.dstOffset
      };
    } catch (error) {
      console.error('Erro ao obter fuso horário:', error);
      return null;
    }
  }

  async getPlaceAutocomplete(input: string, sessionToken?: string): Promise<{ placeId: string; description: string; mainText: string; secondaryText: string }[]> {
    try {
      const response = await mapsClient.placeAutocomplete({
        params: {
          input,
          key: GOOGLE_MAPS_API_KEY,
          language: Language.pt_PT,
          ...(sessionToken && { sessiontoken: sessionToken })
        }
      });

      return response.data.predictions.map(prediction => ({
        placeId: prediction.place_id,
        description: prediction.description,
        mainText: prediction.structured_formatting.main_text,
        secondaryText: prediction.structured_formatting.secondary_text || ''
      }));
    } catch (error) {
      console.error('Erro no autocomplete:', error);
      return [];
    }
  }

  async searchDestinations(input: string): Promise<{
    placeId: string;
    name: string;
    subtitle: string;
    description: string;
    types: string[];
  }[]> {
    try {
      const response = await mapsClient.placeAutocomplete({
        params: {
          input,
          key: GOOGLE_MAPS_API_KEY,
          language: Language.pt_PT,
          types: '(regions)' as any // Apenas cidades, países, regiões
        }
      });

      return response.data.predictions.map(prediction => ({
        placeId: prediction.place_id,
        name: prediction.structured_formatting.main_text,
        subtitle: prediction.structured_formatting.secondary_text || '',
        description: prediction.description,
        types: prediction.types || []
      }));
    } catch (error) {
      console.error('Erro ao pesquisar destinos:', error);
      return [];
    }
  }

  async getDestinationDetails(placeId: string): Promise<{
    placeId: string;
    name: string;
    subtitle: string;
    formattedAddress: string;
    location: { lat: number; lng: number };
    photoUrl: string | null;
    types: string[];
  } | null> {
    try {
      const response = await mapsClient.placeDetails({
        params: {
          place_id: placeId,
          key: GOOGLE_MAPS_API_KEY,
          language: Language.pt_PT,
          fields: [
            'place_id',
            'name',
            'formatted_address',
            'geometry',
            'types',
            'photos',
            'address_components'
          ]
        }
      });

      const place = response.data.result;
      if (!place) return null;

      // Extract country or region for subtitle
      let subtitle = '';
      if (place.address_components) {
        const country = place.address_components.find(c => 
          (c.types as string[]).includes('country')
        );
        const adminArea = place.address_components.find(c => 
          (c.types as string[]).includes('administrative_area_level_1')
        );
        subtitle = adminArea?.long_name || country?.long_name || '';
      }

      // Get photo URL - pegar foto aleatória se houver múltiplas
      let photoUrl: string | null = null;
      if (place.photos && place.photos.length > 0) {
        // Escolher uma foto aleatória
        const randomIndex = Math.floor(Math.random() * Math.min(place.photos.length, 10));
        photoUrl = `https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${place.photos[randomIndex].photo_reference}&key=${GOOGLE_MAPS_API_KEY}`;
      }

      return {
        placeId: place.place_id || placeId,
        name: place.name || '',
        subtitle,
        formattedAddress: place.formatted_address || '',
        location: {
          lat: place.geometry?.location.lat || 0,
          lng: place.geometry?.location.lng || 0
        },
        photoUrl,
        types: place.types || []
      };
    } catch (error) {
      console.error('Erro ao obter detalhes do destino:', error);
      return null;
    }
  }

  calculateDistance(
    point1: { lat: number; lng: number }, 
    point2: { lat: number; lng: number }
  ): number {
    const R = 6371; // Raio da Terra em km
    const dLat = this.toRad(point2.lat - point1.lat);
    const dLng = this.toRad(point2.lng - point1.lng);
    const a = 
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(point1.lat)) * Math.cos(this.toRad(point2.lat)) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c; // Distância em km
  }

  private toRad(deg: number): number {
    return deg * (Math.PI / 180);
  }

  // Obter direções entre dois pontos com modo de transporte
  async getDirections(params: {
    origin: string | { lat: number; lng: number };
    destination: string | { lat: number; lng: number };
    waypoints?: Array<string | { lat: number; lng: number }>;
    mode?: 'driving' | 'walking' | 'bicycling' | 'transit';
  }) {
    try {
      const requestParams: any = {
        origin: typeof params.origin === 'string' ? params.origin : `${params.origin.lat},${params.origin.lng}`,
        destination: typeof params.destination === 'string' ? params.destination : `${params.destination.lat},${params.destination.lng}`,
        mode: params.mode ? TravelMode[params.mode] : TravelMode.walking,
        key: GOOGLE_MAPS_API_KEY,
      };

      // Só adicionar waypoints se existirem
      if (params.waypoints && params.waypoints.length > 0) {
        requestParams.waypoints = params.waypoints.map(wp => 
          typeof wp === 'string' ? wp : `${wp.lat},${wp.lng}`
        );
      }

      const response = await mapsClient.directions({
        params: requestParams,
      });

      if (response.data.status !== 'OK') {
        throw new Error(`Directions API error: ${response.data.status}`);
      }

      const route = response.data.routes[0];
      const leg = route.legs[0];

      return {
        distance: leg.distance,
        duration: leg.duration,
        startAddress: leg.start_address,
        endAddress: leg.end_address,
        startLocation: leg.start_location,
        endLocation: leg.end_location,
        steps: leg.steps.map(step => ({
          distance: step.distance,
          duration: step.duration,
          instruction: step.html_instructions,
          polyline: step.polyline,
          travelMode: step.travel_mode,
          startLocation: step.start_location,
          endLocation: step.end_location,
        })),
        polyline: route.overview_polyline,
      };
    } catch (error) {
      console.error('Error getting directions:', error);
      throw error;
    }
  }

  // Obter rota otimizada com múltiplos transportes
  async getOptimizedRouteWithTransports(
    points: Array<{ lat: number; lng: number; name?: string }>
  ) {
    try {
      const routes = [];
      
      // Para cada par de pontos consecutivos, encontrar o melhor modo de transporte
      for (let i = 0; i < points.length - 1; i++) {
        const origin = points[i];
        const destination = points[i + 1];
        
        // Calcular a distância entre os pontos
        const distance = this.calculateDistance(origin, destination);
        
        // Decidir o melhor modo de transporte baseado na distância
        let mode: 'driving' | 'walking' | 'bicycling' | 'transit' = 'walking';
        
        if (distance > 5) {
          // Distância > 5km, usar transit (transporte público)
          mode = 'transit';
        } else if (distance > 2) {
          // Distância entre 2-5km, usar bicicleta
          mode = 'bicycling';
        } else {
          // Distância < 2km, caminhar
          mode = 'walking';
        }
        
        // Tentar obter direções para este modo
        try {
          const directions = await this.getDirections({
            origin,
            destination,
            mode,
          });
          
          routes.push({
            segmentIndex: i,
            origin: {
              lat: origin.lat,
              lng: origin.lng,
              name: origin.name || `Point ${i + 1}`,
            },
            destination: {
              lat: destination.lat,
              lng: destination.lng,
              name: destination.name || `Point ${i + 2}`,
            },
            mode,
            distance: directions.distance,
            duration: directions.duration,
            polyline: directions.polyline,
            steps: directions.steps,
          });
        } catch (error) {
          // Se falhar, tentar com walking como fallback
          console.warn(`Failed to get directions for mode ${mode}, trying walking`);
          try {
            const directions = await this.getDirections({
              origin,
              destination,
              mode: 'walking',
            });
            
            routes.push({
              segmentIndex: i,
              origin: {
                lat: origin.lat,
                lng: origin.lng,
                name: origin.name || `Point ${i + 1}`,
              },
              destination: {
                lat: destination.lat,
                lng: destination.lng,
                name: destination.name || `Point ${i + 2}`,
              },
              mode: 'walking',
              distance: directions.distance,
              duration: directions.duration,
              polyline: directions.polyline,
              steps: directions.steps,
            });
          } catch (walkingError) {
            console.error('Failed to get walking directions:', walkingError);
            // Criar uma rota de linha reta como último recurso
            routes.push({
              segmentIndex: i,
              origin: {
                lat: origin.lat,
                lng: origin.lng,
                name: origin.name || `Point ${i + 1}`,
              },
              destination: {
                lat: destination.lat,
                lng: destination.lng,
                name: destination.name || `Point ${i + 2}`,
              },
              mode: 'walking',
              distance: { text: `${distance.toFixed(1)} km`, value: distance * 1000 },
              duration: { text: 'Unknown', value: 0 },
              polyline: null,
              steps: [],
            });
          }
        }
      }
      
      return {
        routes,
        totalDistance: routes.reduce((sum, r) => sum + (r.distance?.value || 0), 0),
        totalDuration: routes.reduce((sum, r) => sum + (r.duration?.value || 0), 0),
      };
    } catch (error) {
      console.error('Error getting optimized route:', error);
      throw error;
    }
  }
}

export const mapsService = new MapsService();
