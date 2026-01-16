import { query } from '../../config/database';

export interface Place {
  id: string;
  google_place_id?: string;
  name: string;
  description?: string;
  place_type: string;
  address?: string;
  city?: string;
  country?: string;
  latitude?: number;
  longitude?: number;
  rating?: number;
  price_level?: number;
  opening_hours?: Record<string, any>;
  contact_info?: Record<string, any>;
  images?: string[];
  metadata?: Record<string, any>;
  created_at: Date;
  updated_at: Date;
}

export class PlacesService {
  async createPlace(placeData: Partial<Place>): Promise<Place> {
    const result = await query<Place>(
      `INSERT INTO places (
        google_place_id, name, description, place_type, address, city, country,
        latitude, longitude, rating, price_level, opening_hours, contact_info, images, metadata
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
      RETURNING *`,
      [
        placeData.google_place_id || null,
        placeData.name,
        placeData.description || null,
        placeData.place_type,
        placeData.address || null,
        placeData.city || null,
        placeData.country || null,
        placeData.latitude || null,
        placeData.longitude || null,
        placeData.rating || null,
        placeData.price_level || null,
        JSON.stringify(placeData.opening_hours || {}),
        JSON.stringify(placeData.contact_info || {}),
        JSON.stringify(placeData.images || []),
        JSON.stringify(placeData.metadata || {}),
      ]
    );
    return result.rows[0];
  }

  async searchPlaces(searchQuery: string, location?: { lat: number; lng: number }): Promise<Place[]> {
    let sql = `
      SELECT * FROM places 
      WHERE (name ILIKE $1 OR description ILIKE $1 OR city ILIKE $1 OR address ILIKE $1)
    `;
    const params: any[] = [`%${searchQuery}%`];

    if (location) {
      // Order by distance using Haversine formula approximation
      sql += `
        ORDER BY (
          (latitude - $2) * (latitude - $2) + 
          (longitude - $3) * (longitude - $3)
        ) ASC
      `;
      params.push(location.lat, location.lng);
    } else {
      sql += ' ORDER BY rating DESC NULLS LAST';
    }

    sql += ' LIMIT 50';

    const result = await query<Place>(sql, params);
    return result.rows;
  }

  async getPlaceById(placeId: string): Promise<Place | null> {
    const result = await query<Place>('SELECT * FROM places WHERE id = $1', [placeId]);
    return result.rows[0] || null;
  }

  async getPlaceByGoogleId(googlePlaceId: string): Promise<Place | null> {
    const result = await query<Place>('SELECT * FROM places WHERE google_place_id = $1', [googlePlaceId]);
    return result.rows[0] || null;
  }

  async getNearbyPlaces(latitude: number, longitude: number, radiusKm: number = 10, type?: string): Promise<Place[]> {
    // Approximate degrees for the radius (1 degree ≈ 111 km at equator)
    const latDelta = radiusKm / 111;
    const lngDelta = radiusKm / (111 * Math.cos(latitude * Math.PI / 180));

    let sql = `
      SELECT *, 
        (6371 * acos(cos(radians($1)) * cos(radians(latitude)) * cos(radians(longitude) - radians($2)) + sin(radians($1)) * sin(radians(latitude)))) AS distance
      FROM places
      WHERE latitude BETWEEN $1 - $3 AND $1 + $3
        AND longitude BETWEEN $2 - $4 AND $2 + $4
    `;
    const params: any[] = [latitude, longitude, latDelta, lngDelta];

    if (type) {
      sql += ` AND place_type = $5`;
      params.push(type);
    }

    sql += ' ORDER BY distance LIMIT 50';

    const result = await query<Place & { distance: number }>(sql, params);
    return result.rows;
  }

  async getPopularPlaces(destination: string): Promise<Place[]> {
    const result = await query<Place>(
      `SELECT * FROM places 
       WHERE (city ILIKE $1 OR country ILIKE $1) 
       ORDER BY rating DESC NULLS LAST 
       LIMIT 20`,
      [`%${destination}%`]
    );
    return result.rows;
  }

  async getPlacesByType(placeType: string, city?: string): Promise<Place[]> {
    let sql = 'SELECT * FROM places WHERE place_type = $1';
    const params: any[] = [placeType];

    if (city) {
      sql += ' AND city ILIKE $2';
      params.push(`%${city}%`);
    }

    sql += ' ORDER BY rating DESC NULLS LAST LIMIT 50';

    const result = await query<Place>(sql, params);
    return result.rows;
  }

  async updatePlace(placeId: string, placeData: Partial<Place>): Promise<Place | null> {
    const fields: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    const allowedFields = [
      'name', 'description', 'place_type', 'address', 'city', 'country',
      'latitude', 'longitude', 'rating', 'price_level', 'opening_hours',
      'contact_info', 'images', 'metadata'
    ];

    for (const field of allowedFields) {
      if (placeData[field as keyof Place] !== undefined) {
        fields.push(`${field} = $${paramIndex}`);
        const value = ['opening_hours', 'contact_info', 'images', 'metadata'].includes(field)
          ? JSON.stringify(placeData[field as keyof Place])
          : placeData[field as keyof Place];
        values.push(value);
        paramIndex++;
      }
    }

    if (fields.length === 0) {
      return this.getPlaceById(placeId);
    }

    values.push(placeId);
    const result = await query<Place>(
      `UPDATE places SET ${fields.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      values
    );
    return result.rows[0] || null;
  }

  async deletePlace(placeId: string): Promise<boolean> {
    const result = await query('DELETE FROM places WHERE id = $1', [placeId]);
    return (result.rowCount ?? 0) > 0;
  }
}

export const placesService = new PlacesService();
