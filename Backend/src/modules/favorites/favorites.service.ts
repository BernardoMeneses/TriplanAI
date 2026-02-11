import { query } from '../../config/database';
import { Place } from '../places/places.service';

export interface UserFavorite {
  id: string;
  user_id: string;
  place_id: string;
  notes?: string;
  created_at: Date;
  place?: Place;
}

export class FavoritesService {
  async addFavorite(userId: string, placeId: string, notes?: string): Promise<UserFavorite> {
    const result = await query<UserFavorite>(
      `INSERT INTO user_favorites (user_id, place_id, notes)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, place_id) DO UPDATE SET notes = $3
       RETURNING *`,
      [userId, placeId, notes || null]
    );
    return result.rows[0];
  }

  async removeFavorite(userId: string, placeId: string): Promise<boolean> {
    const result = await query(
      'DELETE FROM user_favorites WHERE user_id = $1 AND place_id = $2',
      [userId, placeId]
    );
    return (result.rowCount ?? 0) > 0;
  }

  async getFavorites(userId: string): Promise<UserFavorite[]> {
    const result = await query<UserFavorite>(
      `SELECT 
        uf.*,
        json_build_object(
          'id', p.id,
          'google_place_id', p.google_place_id,
          'name', p.name,
          'description', p.description,
          'place_type', p.place_type,
          'address', p.address,
          'city', p.city,
          'country', p.country,
          'latitude', p.latitude,
          'longitude', p.longitude,
          'rating', p.rating,
          'price_level', p.price_level,
          'opening_hours', p.opening_hours,
          'contact_info', p.contact_info,
          'images', p.images,
          'metadata', p.metadata,
          'created_at', p.created_at,
          'updated_at', p.updated_at
        ) as place
       FROM user_favorites uf
       INNER JOIN places p ON uf.place_id = p.id
       WHERE uf.user_id = $1
       ORDER BY uf.created_at DESC`,
      [userId]
    );
    return result.rows;
  }

  async isFavorite(userId: string, placeId: string): Promise<boolean> {
    const result = await query(
      'SELECT 1 FROM user_favorites WHERE user_id = $1 AND place_id = $2',
      [userId, placeId]
    );
    return result.rows.length > 0;
  }
}
