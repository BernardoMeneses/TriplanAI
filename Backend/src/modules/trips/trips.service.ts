import { query } from '../../config/database';

export interface Trip {
  id: string;
  user_id: string;
  title: string;
  description?: string;
  destination_city: string;
  destination_country: string;
  start_date: Date;
  end_date: Date;
  budget?: number;
  currency: string;
  status: string;
  trip_type?: string;
  number_of_travelers: number;
  preferences?: Record<string, any>;
  created_at: Date;
  updated_at: Date;
}

export class TripsService {
  async createTrip(userId: string, tripData: Partial<Trip>): Promise<Trip> {
    const result = await query<Trip>(
      `INSERT INTO trips (
        user_id, title, description, destination_city, destination_country,
        start_date, end_date, budget, currency, status, trip_type, number_of_travelers, preferences
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      RETURNING *`,
      [
        userId,
        tripData.title,
        tripData.description || null,
        tripData.destination_city,
        tripData.destination_country,
        tripData.start_date,
        tripData.end_date,
        tripData.budget || null,
        tripData.currency || 'EUR',
        tripData.status || 'planning',
        tripData.trip_type || null,
        tripData.number_of_travelers || 1,
        JSON.stringify(tripData.preferences || {}),
      ]
    );
    return result.rows[0];
  }

  async getTripById(tripId: string): Promise<Trip | null> {
    const result = await query<Trip>('SELECT * FROM trips WHERE id = $1', [tripId]);
    return result.rows[0] || null;
  }

  async getTripsByUser(userId: string): Promise<Trip[]> {
    const result = await query<Trip>(
      'SELECT * FROM trips WHERE user_id = $1 ORDER BY start_date DESC',
      [userId]
    );
    return result.rows;
  }

  async updateTrip(tripId: string, tripData: Partial<Trip>): Promise<Trip | null> {
    const fields: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    const allowedFields = [
      'title', 'description', 'destination_city', 'destination_country',
      'start_date', 'end_date', 'budget', 'currency', 'status',
      'trip_type', 'number_of_travelers', 'preferences'
    ];

    for (const field of allowedFields) {
      if (tripData[field as keyof Trip] !== undefined) {
        fields.push(`${field} = $${paramIndex}`);
        const value = field === 'preferences' 
          ? JSON.stringify(tripData[field as keyof Trip])
          : tripData[field as keyof Trip];
        values.push(value);
        paramIndex++;
      }
    }

    if (fields.length === 0) {
      return this.getTripById(tripId);
    }

    values.push(tripId);
    const result = await query<Trip>(
      `UPDATE trips SET ${fields.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      values
    );
    return result.rows[0] || null;
  }

  async deleteTrip(tripId: string): Promise<boolean> {
    const result = await query('DELETE FROM trips WHERE id = $1', [tripId]);
    return (result.rowCount ?? 0) > 0;
  }
}

export const tripsService = new TripsService();
