import { Client, GeocodeResult, PlaceInputType, TravelMode, Language } from '@googlemaps/google-maps-services-js';
import { getDirectionsRoute } from '../../services/googleRoutesDirectionsApi.service';

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
  photoUrl?: string; // Adicionado para suportar imagem principal
  photoReferences?: Array<{ reference: string; type: string }>; // Referências para regenerar URLs frescas
  phoneNumber?: string;
  website?: string;
}

export class MapsService {
  private countryCodeCache = new Map<string, string | null>();

  private normalizeLanguageCode(language?: string): string {
    const value = (language || '').trim();
    if (!value) return Language.pt_PT;
    return value;
  }

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

  async getPlaceDetails(placeId: string, sessionToken?: string, language?: string): Promise<PlaceDetails | null> {
    try {
      const languageCode = this.normalizeLanguageCode(language);
      const response = await mapsClient.placeDetails({
        params: {
          place_id: placeId,
          key: GOOGLE_MAPS_API_KEY,
          language: languageCode as any,
          ...(sessionToken && { sessiontoken: sessionToken }),
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

      // Usar novo método para gerar URLs de imagens inteligentes
      const { photos, photoUrl, photoReferences } = this.getImageUrlsForPlace(place, place.name || 'place');

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
        photos,
        photoUrl, // Campo com URL confiável (Google Maps ou Unsplash)
        photoReferences, // Armazenar referências para regenerar URLs depois (evita expiração)
        phoneNumber: place.formatted_phone_number,
        website: place.website
      };
    } catch (error) {
      console.error('Erro ao obter detalhes do lugar:', error);
      return null;
    }
  }

  async searchPlaces(query: string, location?: { lat: number; lng: number }, radius?: number, sessionToken?: string, country?: string, language?: string): Promise<PlaceDetails[]> {
    try {
      const languageCode = this.normalizeLanguageCode(language);
      const trimmedQuery = query.trim();
      if (!trimmedQuery) return [];

      const effectiveRadius = radius && radius > 0 ? radius : 15000;
      const countryCode = await this.resolveCountryCode(country);
      const countryLabel = (country || '').trim();

      console.log(`[MapsService] searchPlaces input="${trimmedQuery}"`);
      // First try Place Autocomplete for better fuzzy/partial matching
      try {
        const autoParams: any = {
          input: trimmedQuery,
          key: GOOGLE_MAPS_API_KEY,
          language: languageCode,
        };

        if (countryCode) {
          autoParams.components = `country:${countryCode}`;
          // strictbounds helps keep results within the country when combined with components
          autoParams.strictbounds = true;
          console.log(`[MapsService] using country filter for autocomplete: ${countryCode}`);
        }
        if (location) {
          autoParams.location = location;
          autoParams.radius = effectiveRadius;
        }
        if (sessionToken) {
          autoParams.sessiontoken = sessionToken;
          console.log(`[MapsService] using sessionToken for autocomplete: ${sessionToken}`);
        }

        const autoResponse = await mapsClient.placeAutocomplete({ params: autoParams });
        const predictions = autoResponse.data.predictions || [];
        console.log(`[MapsService] autocomplete returned ${predictions.length} predictions for "${trimmedQuery}"`);

        if (predictions.length > 0) {
          const detailedPlaces = await Promise.all(predictions.slice(0, 20).map(async (prediction) => {
            const details = await this.getPlaceDetails(prediction.place_id, sessionToken, languageCode);
            if (details) return details;

            return {
              placeId: prediction.place_id || '',
              name: prediction.structured_formatting?.main_text || prediction.description || '',
              formattedAddress: prediction.description || '',
              location: { lat: 0, lng: 0 },
              types: prediction.types || [],
              rating: undefined,
              priceLevel: undefined,
              openingHours: undefined,
              photos: [],
              photoUrl: undefined,
              phoneNumber: undefined,
              website: undefined,
            } as PlaceDetails;
          }));

          return this.applyLocalityFilter(detailedPlaces, location, effectiveRadius);
        }
      } catch (autocompleteError) {
        // If autocomplete fails, fall back to textSearch below
        console.warn('Place autocomplete failed, falling back to textSearch:', autocompleteError);
      }

      // Fallback: use Text Search for broader queries
      const params: any = {
        query: trimmedQuery,
        key: GOOGLE_MAPS_API_KEY,
        language: languageCode,
      };

      // Bias textSearch to the resolved country when available.
      if (countryCode) {
        params.region = countryCode.toLowerCase();
        console.log(`[MapsService] using region bias for textSearch: ${countryCode}`);
      }

      // Also append the original country label (in any language/script) to strengthen locality intent.
      if (countryLabel && !this.includesNormalized(trimmedQuery, countryLabel)) {
        params.query = `${trimmedQuery}, ${countryLabel}`;
        console.log(`[MapsService] appending country label to textSearch query: ${params.query}`);
      }

      if (location) {
        params.location = location;
        params.radius = effectiveRadius;
      }

      const response = await mapsClient.textSearch({ params });
      const places = response.data.results.slice(0, 20);
      console.log(`[MapsService] textSearch returned ${places.length} results for "${trimmedQuery}"`);

      // Buscar detalhes completos para cada resultado
      const detailedPlaces = await Promise.all(places.map(async (place) => {
        let details = await this.getPlaceDetails(place.place_id || '', sessionToken, languageCode);
        // Copiar diretamente o campo photoUrl e photos do details
        return details || {
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
          openingHours: undefined,
          ...this.getImageUrlsForPlace(place, place.name || 'place'),
          phoneNumber: undefined,
          website: undefined,
        } as PlaceDetails;
      }));

      return this.applyLocalityFilter(detailedPlaces, location, effectiveRadius);
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

      return response.data.results.slice(0, 20).map(place => {
        const { photos, photoUrl } = this.getImageUrlsForPlace(place, place.name || 'place');
        return {
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
          photos,
          photoUrl
        };
      });
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

      // Get photo URL - usar novo método inteligente
      const { photos, photoUrl } = this.getImageUrlsForPlace(place, place.name || 'place');

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

  private normalizeLookupValue(value: string): string {
    return value
      .trim()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase();
  }

  private includesNormalized(text: string, term: string): boolean {
    return this.normalizeLookupValue(text).includes(this.normalizeLookupValue(term));
  }

  private applyLocalityFilter(
    places: PlaceDetails[],
    location?: { lat: number; lng: number },
    radiusMeters: number = 5000,
  ): PlaceDetails[] {
    if (!location || places.length === 0) {
      return places;
    }

    const minRadiusMeters = Math.max(radiusMeters, 1000);
    const maxRadiusMeters = Math.max(minRadiusMeters, 120000);
    const targetLocalResults = 8;

    const rankedByDistance = places
      .filter((place) => {
        const lat = place.location?.lat;
        const lng = place.location?.lng;
        return typeof lat === 'number' && typeof lng === 'number' && !(lat === 0 && lng === 0);
      })
      .map((place) => ({
        place,
        distanceKm: this.calculateDistance(location, place.location),
      }))
      .filter((item) => Number.isFinite(item.distanceKm))
      .sort((a, b) => a.distanceKm - b.distanceKm);

    if (rankedByDistance.length === 0) {
      return [];
    }

    const radiusSteps = [1, 1.5, 2, 3, 4, 6, 8]
      .map((factor) => Math.min(Math.round(minRadiusMeters * factor), maxRadiusMeters))
      .filter((value, index, arr) => arr.indexOf(value) === index);

    if (!radiusSteps.includes(maxRadiusMeters)) {
      radiusSteps.push(maxRadiusMeters);
    }

    let bestInRange: Array<{ place: PlaceDetails; distanceKm: number }> = [];

    for (const currentRadius of radiusSteps) {
      const currentRadiusKm = currentRadius / 1000;
      const inRange = rankedByDistance.filter((item) => item.distanceKm <= currentRadiusKm);

      if (inRange.length > 0) {
        bestInRange = inRange;
      }

      if (inRange.length >= targetLocalResults) {
        return inRange.map((item) => item.place);
      }
    }

    return bestInRange.map((item) => item.place);
  }

  private async resolveCountryCode(country?: string): Promise<string | undefined> {
    if (!country) return undefined;

    const trimmed = country.trim();
    if (!trimmed) return undefined;

    if (/^[a-z]{2}$/i.test(trimmed)) {
      return trimmed.toUpperCase();
    }

    const cacheKey = this.normalizeLookupValue(trimmed);
    if (this.countryCodeCache.has(cacheKey)) {
      const cached = this.countryCodeCache.get(cacheKey);
      return cached || undefined;
    }

    try {
      const response = await mapsClient.geocode({
        params: {
          address: trimmed,
          key: GOOGLE_MAPS_API_KEY,
          language: 'en' as any,
        },
      });

      for (const result of response.data.results) {
        for (const component of result.address_components) {
          const types = component.types as string[];
          if (!types.includes('country')) continue;

          const shortName = (component.short_name || '').trim().toUpperCase();
          if (/^[A-Z]{2}$/.test(shortName)) {
            this.countryCodeCache.set(cacheKey, shortName);
            return shortName;
          }
        }
      }
    } catch (error) {
      console.warn(`[MapsService] could not resolve country code for "${trimmed}"`, error);
    }

    this.countryCodeCache.set(cacheKey, null);
    return undefined;
  }

  // Obter direções entre dois pontos com modo de transporte (usando nova Google Routes API)
  async getDirections(params: {
    origin: string | { lat: number; lng: number };
    destination: string | { lat: number; lng: number };
    waypoints?: Array<string | { lat: number; lng: number }>;
    mode?: 'driving' | 'walking' | 'bicycling' | 'transit';
  }) {
    try {
      // Adaptar origem/destino para formato { lat, lng }
      const origin = typeof params.origin === 'string'
        ? this.parseLatLngString(params.origin)
        : params.origin;
      const destination = typeof params.destination === 'string'
        ? this.parseLatLngString(params.destination)
        : params.destination;

      // Nova API ainda não suporta waypoints múltiplos (apenas um par origem-destino)
      const travelMode = params.mode || 'walking';

      const apiResponse = await getDirectionsRoute({
        origin,
        destination,
        travelMode,
        languageCode: 'pt-PT',
      });

      if (!apiResponse.routes || apiResponse.routes.length === 0) {
        // Mensagem amigável para frontend
        return {
          error: 'Não foi encontrada nenhuma rota para o modo de transporte selecionado. Pode não haver transporte público disponível para este trajeto ou horário.'
        };
      }
      const route = apiResponse.routes[0];
      const leg = route.legs && route.legs[0];

      // Log polylines e modos de transporte
      if (route.polyline && route.polyline.encodedPolyline) {
        console.log('[MapsService] Polyline geral:', route.polyline.encodedPolyline);
      }
      if (leg && leg.steps && leg.steps.length > 0) {
        leg.steps.forEach((step: any, idx: any) => {
          console.log(`[MapsService] Step ${idx} modo: ${step.travelMode}, polyline:`, step.polyline?.encodedPolyline);
        });
      }

      return {
        distance: leg?.distanceMeters ? { value: leg.distanceMeters, text: `${(leg.distanceMeters/1000).toFixed(2)} km` } : undefined,
        duration: leg?.duration ? { value: leg.duration, text: `${Math.round(leg.duration/60)} min` } : undefined,
        startAddress: leg?.startLocation,
        endAddress: leg?.endLocation,
        startLocation: leg?.startLocation,
        endLocation: leg?.endLocation,
        steps: leg?.steps?.map((step: any) => ({
          distance: step.distanceMeters ? { value: step.distanceMeters, text: `${step.distanceMeters} m` } : undefined,
          duration: step.duration ? { value: step.duration, text: `${Math.round(step.duration/60)} min` } : undefined,
          instruction: step.navigationInstruction?.instructions,
          polyline: step.polyline,
          travelMode: step.travelMode,
          startLocation: step.startLocation,
          endLocation: step.endLocation,
        })) || [],
        polyline: route.polyline,
      };
    } catch (error) {
      console.error('Error getting directions:', error);
      // Mensagem amigável para erros inesperados
      return {
        error: 'Ocorreu um erro ao obter direções. Tente novamente ou escolha outro modo de transporte.'
      };
    }
  }

  // Utilitário para converter string "lat,lng" em objeto { lat, lng }
  private parseLatLngString(str: string): { lat: number; lng: number } {
    const [lat, lng] = str.split(',').map(Number);
    return { lat, lng };
  }

  /**
   * Gera URLs de imagens confiáveis para um place (SEMPRE FRESCAS, não cached)
   * Estrutura armazenada na BD: { photos: [{ reference: "...", type: "google" }, ...] }
   * 
   * Prioridade:
   * 1. Fotos do Google Maps API (regenera URL com API key atual)
   * 2. Busca Unsplash com keywords inteligentes
   */
  private getImageUrlsForPlace(
    place: any,
    placeName: string
  ): { photos: string[]; photoUrl: string; photoReferences: Array<{ reference: string; type: string }> } {
    const photos: string[] = [];
    const photoReferences: Array<{ reference: string; type: string }> = [];
    let photoUrl = '';

    // 1. Tentar Google Maps Photos - guardar REFERENCE para regenerar URL depois
    if (place.photos && Array.isArray(place.photos) && place.photos.length > 0) {
      place.photos.slice(0, 5).forEach((photo: any) => {
        if (photo.photo_reference) {
          const photoRefObj = { reference: photo.photo_reference, type: 'google' };
          photoReferences.push(photoRefObj);
          
          // Gerar URL fresca com API key ATUAL
          const freshUrl = `https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${photo.photo_reference}&key=${GOOGLE_MAPS_API_KEY}`;
          photos.push(freshUrl);
        }
      });
      photoUrl = photos[0];
      console.log(`[MapsService] Guardando ${photoReferences.length} referências do Google Maps para "${placeName}"`);
    }

    // 2. Se não houver fotos do Google, usar Unsplash com query inteligente
    if (photos.length === 0) {
      const keywords = this.extractKeywordsFromPlace(place, placeName);
      
      for (const keyword of keywords.slice(0, 3)) {
        const unsplashQuery = encodeURIComponent(keyword);
        const unsplashUrl = `https://source.unsplash.com/800x600/?${unsplashQuery}`;
        
        photos.push(unsplashUrl);
        photoReferences.push({ 
          reference: unsplashQuery, 
          type: 'unsplash'
        });
      }
      
      photoUrl = photos[0] || 'https://source.unsplash.com/800x600/?travel';
      console.log(`[MapsService] Usando Unsplash para "${placeName}": ${keywords.slice(0, 3).join(', ')}`);
    }

    return { photos, photoUrl, photoReferences };
  }

  /**
   * Regenera URLs frescas a partir das referências armazenadas na BD
   * Chamado sempre que precisar exibir imagens
   */
  regeneratePhotoUrlsFromReferences(
    photoReferences: Array<{ reference: string; type: string }>
  ): { photos: string[]; photoUrl: string } {
    const photos: string[] = [];

    for (const ref of photoReferences) {
      if (ref.type === 'google') {
        // Gerar URL FRESCA com API key ATUAL (evita expiração)
        const url = `https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${ref.reference}&key=${GOOGLE_MAPS_API_KEY}`;
        photos.push(url);
      } else if (ref.type === 'unsplash') {
        // Unsplash URL é sempre fresca
        const url = `https://source.unsplash.com/800x600/?${ref.reference}`;
        photos.push(url);
      }
    }

    return {
      photos,
      photoUrl: photos[0] || 'https://source.unsplash.com/800x600/?travel'
    };
  }

  /**
   * Extrai keywords relevantes do place para busca de imagens
   */
  private extractKeywordsFromPlace(place: any, placeName: string): string[] {
    const keywords: string[] = [];
    
    // 1. Usar tipos do place se disponível
    if (place.types && Array.isArray(place.types)) {
      const typeKeywords: { [key: string]: string } = {
        'museum': 'museum architecture',
        'park': 'park nature landscape',
        'restaurant': 'restaurant food dining',
        'lodging': 'hotel accommodation',
        'hotel': 'luxury hotel',
        'cafe': 'cafe coffee',
        'bar': 'bar night life',
        'shopping_mall': 'shopping mall retail',
        'tourist_attraction': 'tourist attraction landmark',
        'church': 'church architecture religious',
        'temple': 'temple architecture religious',
        'beach': 'beach sea ocean',
        'mountain': 'mountain landscape nature',
        'lake': 'lake water landscape',
        'theater': 'theater entertainment',
        'stadium': 'stadium sports',
        'amusement_park': 'amusement park fun rides',
        'hiking_area': 'hiking trail mountain',
        'zoo': 'zoo animals wildlife',
        'aquarium': 'aquarium marine life',
      };

      for (const type of place.types) {
        if (typeKeywords[type]) {
          keywords.push(typeKeywords[type]);
        }
      }
    }

    // 2. Usar o nome do place como fallback
    if (keywords.length === 0) {
      keywords.push(placeName);
    }

    // 3. Adicionar keywords genéricas como último recurso
    keywords.push('travel destination');
    keywords.push('scenic landmark');

    return keywords;
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
