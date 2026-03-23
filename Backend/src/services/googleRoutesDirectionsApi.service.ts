// src/services/googleRoutesDirectionsApi.service.ts
import axios from 'axios';

const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY || '';
const BASE_URL = 'https://routes.googleapis.com/directions/v2:computeRoutes';

const mapTravelMode = (mode: string): string => {
  const modes: Record<string, string> = {
    driving: 'DRIVE',
    walking: 'WALK',
    bicycling: 'BICYCLE',
    transit: 'TRANSIT'
  };
  return modes[mode] || 'DRIVE';
};

export async function getDirectionsRoute({
  origin,
  destination,
  travelMode = 'driving',
  languageCode = 'pt-PT',
}: {
  origin: { lat: number; lng: number };
  destination: { lat: number; lng: number };
  travelMode?: string;
  languageCode?: string;
}) {
  const requestBody = {
    origin: {
      location: {
        latLng: {
          latitude: origin.lat,
          longitude: origin.lng,
        },
      },
    },
    destination: {
      location: {
        latLng: {
          latitude: destination.lat,
          longitude: destination.lng,
        },
      },
    },
    travelMode: mapTravelMode(travelMode),
    languageCode,
    computeAlternativeRoutes: false,
    routeModifiers: {},
    polylineEncoding: 'ENCODED_POLYLINE',
    units: 'METRIC',
  };

  const response = await axios.post(
    BASE_URL + `?key=${GOOGLE_MAPS_API_KEY}`,
    requestBody,
    {
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-FieldMask': '*',
      },
    }
  );
  return response.data;
}
