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

  async exportTrip(tripId: string): Promise<any> {
    // Buscar dados da trip
    const tripResult = await query<Trip>('SELECT * FROM trips WHERE id = $1', [tripId]);
    const trip = tripResult.rows[0];
    
    if (!trip) {
      throw new Error('Viagem não encontrada');
    }

    // Buscar itinerários
    const itinerariesResult = await query(
      `SELECT * FROM itineraries WHERE trip_id = $1 ORDER BY day_number`,
      [tripId]
    );
    const itineraries = itinerariesResult.rows;

    // Buscar items dos itinerários
    const itineraryIds = itineraries.map((it: any) => it.id);
    let itineraryItems: any[] = [];
    
    if (itineraryIds.length > 0) {
      const itemsResult = await query(
        `SELECT ii.*, p.name as place_name, p.google_place_id, p.address, p.city, 
                p.country, p.latitude, p.longitude, p.rating, p.images
         FROM itinerary_items ii
         LEFT JOIN places p ON ii.place_id = p.id
         WHERE ii.itinerary_id = ANY($1)
         ORDER BY ii.order_index`,
        [itineraryIds]
      );
      itineraryItems = itemsResult.rows;
    }

    // Estruturar os dados para export
    const exportData = {
      version: '1.0',
      exportedAt: new Date().toISOString(),
      trip: {
        title: trip.title,
        description: trip.description,
        destination_city: trip.destination_city,
        destination_country: trip.destination_country,
        start_date: trip.start_date,
        end_date: trip.end_date,
        budget: trip.budget,
        currency: trip.currency,
        trip_type: trip.trip_type,
        number_of_travelers: trip.number_of_travelers,
        preferences: trip.preferences,
      },
      itineraries: itineraries.map((itinerary: any) => ({
        day_number: itinerary.day_number,
        date: itinerary.date,
        title: itinerary.title,
        description: itinerary.description,
        notes: itinerary.notes,
        items: itineraryItems
          .filter((item: any) => item.itinerary_id === itinerary.id)
          .map((item: any) => ({
            title: item.title,
            description: item.description,
            start_time: item.start_time,
            end_time: item.end_time,
            duration_minutes: item.duration_minutes,
            item_type: item.item_type,
            cost: item.cost,
            notes: item.notes,
            place: item.place_id ? {
              name: item.place_name,
              google_place_id: item.google_place_id,
              address: item.address,
              city: item.city,
              country: item.country,
              latitude: item.latitude,
              longitude: item.longitude,
              rating: item.rating,
              images: item.images,
            } : null,
          })),
      })),
    };

    return exportData;
  }

  async importTrip(userId: string, importData: any): Promise<Trip> {
    // Validar estrutura do JSON
    if (!importData.trip || !importData.version) {
      throw new Error('Formato de importação inválido');
    }

    const tripData = importData.trip;

    // Criar nova trip para o usuário
    const newTrip = await this.createTrip(userId, {
      title: tripData.title,
      description: tripData.description,
      destination_city: tripData.destination_city,
      destination_country: tripData.destination_country,
      start_date: tripData.start_date,
      end_date: tripData.end_date,
      budget: tripData.budget,
      currency: tripData.currency,
      trip_type: tripData.trip_type,
      number_of_travelers: tripData.number_of_travelers,
      preferences: tripData.preferences,
      status: 'planning',
    });

    // Importar itinerários se existirem
    if (importData.itineraries && Array.isArray(importData.itineraries)) {
      for (const itineraryData of importData.itineraries) {
        // Criar itinerário
        const itineraryResult = await query(
          `INSERT INTO itineraries (trip_id, day_number, date, title, description, notes)
           VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING *`,
          [
            newTrip.id,
            itineraryData.day_number,
            itineraryData.date,
            itineraryData.title || null,
            itineraryData.description || null,
            itineraryData.notes || null,
          ]
        );
        const newItinerary = itineraryResult.rows[0];

        // Importar items do itinerário
        if (itineraryData.items && Array.isArray(itineraryData.items)) {
          for (let i = 0; i < itineraryData.items.length; i++) {
            const itemData = itineraryData.items[i];
            let placeId = null;

            // Se tem dados de place, criar/buscar o place
            if (itemData.place && itemData.place.google_place_id) {
              // Tentar buscar place existente
              const existingPlace = await query(
                'SELECT id FROM places WHERE google_place_id = $1',
                [itemData.place.google_place_id]
              );

              if (existingPlace.rows.length > 0) {
                placeId = existingPlace.rows[0].id;
              } else {
                // Criar novo place
                const placeResult = await query(
                  `INSERT INTO places (name, google_place_id, address, city, country, latitude, longitude, rating, images)
                   VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                   RETURNING id`,
                  [
                    itemData.place.name,
                    itemData.place.google_place_id,
                    itemData.place.address || null,
                    itemData.place.city || null,
                    itemData.place.country || null,
                    itemData.place.latitude || null,
                    itemData.place.longitude || null,
                    itemData.place.rating || null,
                    JSON.stringify(itemData.place.images || []),
                  ]
                );
                placeId = placeResult.rows[0].id;
              }
            }

            // Criar item do itinerário
            await query(
              `INSERT INTO itinerary_items (
                itinerary_id, place_id, order_index, title, description,
                start_time, end_time, duration_minutes, item_type, status, cost, notes
              ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
              [
                newItinerary.id,
                placeId,
                i,
                itemData.title,
                itemData.description || null,
                itemData.start_time || null,
                itemData.end_time || null,
                itemData.duration_minutes || null,
                itemData.item_type || 'activity',
                'pending',
                itemData.cost || null,
                itemData.notes || null,
              ]
            );
          }
        }
      }
    }

    return newTrip;
  }
}

export const tripsService = new TripsService();
