// src/services/googleRoutesApi.service.ts
import axios from 'axios';
import { Waypoint, DistanceMatrixResult, TravelModeType } from '../modules/routes/routes.service';

const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY || '';

const BASE_URL = 'https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix';

const mapTravelMode = (mode: TravelModeType): string => {
  const modes: Record<TravelModeType, string> = {
    driving: 'DRIVE',
    walking: 'WALK',
    bicycling: 'BICYCLE',
    transit: 'TRANSIT'
  };
  return modes[mode] || 'DRIVE';
};

export async function getRouteMatrix(origins: Waypoint[], destinations: Waypoint[], travelMode: TravelModeType = 'driving') {
  const requestBody = {
    origins: origins.map(wp => ({
      waypoint: {
        location: {
          latLng: {
            latitude: wp.latitude,
            longitude: wp.longitude
          }
        }
      }
    })),
    destinations: destinations.map(wp => ({
      waypoint: {
        location: {
          latLng: {
            latitude: wp.latitude,
            longitude: wp.longitude
          }
        }
      }
    })),
    travelMode: mapTravelMode(travelMode),
    units: 'METRIC',
    languageCode: 'en-US',
  };

  const response = await axios.post(BASE_URL + `?key=${GOOGLE_MAPS_API_KEY}`,
    requestBody,
    {
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-FieldMask': 'originIndex,destinationIndex,duration,distanceMeters,status',
      },
    }
  );
  return response.data;
}
