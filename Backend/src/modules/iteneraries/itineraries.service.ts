import { query, transaction } from '../../config/database';

export interface Itinerary {
  id: string;
  trip_id: string;
  day_number: number;
  date: Date;
  title?: string;
  description?: string;
  notes?: string;
  created_at: Date;
  updated_at: Date;
}

export interface ItineraryItem {
  id: string;
  itinerary_id: string;
  place_id?: string;
  order_index: number;
  title: string;
  description?: string;
  start_time?: string;
  end_time?: string;
  duration_minutes?: number;
  item_type?: string;
  status: string;
  cost?: number;
  notes?: string;
  booking_reference?: string;
  created_at: Date;
  updated_at: Date;
}

export interface ItineraryWithItems extends Itinerary {
  items: ItineraryItem[];
}

export class ItinerariesService {
  async createItinerary(tripId: string, itineraryData: Partial<Itinerary>): Promise<Itinerary> {
    const result = await query<Itinerary>(
      `INSERT INTO itineraries (trip_id, day_number, date, title, description, notes)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        tripId,
        itineraryData.day_number,
        itineraryData.date,
        itineraryData.title || null,
        itineraryData.description || null,
        itineraryData.notes || null,
      ]
    );
    return result.rows[0];
  }

  async getItinerariesByTrip(tripId: string): Promise<ItineraryWithItems[]> {
    const itineraries = await query<Itinerary>(
      'SELECT * FROM itineraries WHERE trip_id = $1 ORDER BY day_number',
      [tripId]
    );

    const result: ItineraryWithItems[] = [];
    
    for (const itinerary of itineraries.rows) {
      const items = await query<ItineraryItem>(
        'SELECT * FROM itinerary_items WHERE itinerary_id = $1 ORDER BY order_index',
        [itinerary.id]
      );
      result.push({ ...itinerary, items: items.rows });
    }

    return result;
  }

  async getItineraryById(itineraryId: string): Promise<ItineraryWithItems | null> {
    const itineraryResult = await query<Itinerary>(
      'SELECT * FROM itineraries WHERE id = $1',
      [itineraryId]
    );

    if (itineraryResult.rows.length === 0) {
      return null;
    }

    const itinerary = itineraryResult.rows[0];
    const items = await query<ItineraryItem>(
      'SELECT * FROM itinerary_items WHERE itinerary_id = $1 ORDER BY order_index',
      [itineraryId]
    );

    return { ...itinerary, items: items.rows };
  }

  async updateItinerary(itineraryId: string, itineraryData: Partial<Itinerary>): Promise<Itinerary | null> {
    const fields: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    const allowedFields = ['day_number', 'date', 'title', 'description', 'notes'];

    for (const field of allowedFields) {
      if (itineraryData[field as keyof Itinerary] !== undefined) {
        fields.push(`${field} = $${paramIndex}`);
        values.push(itineraryData[field as keyof Itinerary]);
        paramIndex++;
      }
    }

    if (fields.length === 0) {
      const result = await query<Itinerary>('SELECT * FROM itineraries WHERE id = $1', [itineraryId]);
      return result.rows[0] || null;
    }

    values.push(itineraryId);
    const result = await query<Itinerary>(
      `UPDATE itineraries SET ${fields.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      values
    );
    return result.rows[0] || null;
  }

  async deleteItinerary(itineraryId: string): Promise<boolean> {
    const result = await query('DELETE FROM itineraries WHERE id = $1', [itineraryId]);
    return (result.rowCount ?? 0) > 0;
  }

  async addItem(itineraryId: string, item: Partial<ItineraryItem>): Promise<ItineraryItem> {
    // Get the next order index
    const maxOrder = await query<{ max: number }>(
      'SELECT COALESCE(MAX(order_index), 0) as max FROM itinerary_items WHERE itinerary_id = $1',
      [itineraryId]
    );
    const orderIndex = (maxOrder.rows[0]?.max || 0) + 1;

    const result = await query<ItineraryItem>(
      `INSERT INTO itinerary_items (
        itinerary_id, place_id, order_index, title, description,
        start_time, end_time, duration_minutes, item_type, status, cost, notes, booking_reference
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      RETURNING *`,
      [
        itineraryId,
        item.place_id || null,
        item.order_index ?? orderIndex,
        item.title,
        item.description || null,
        item.start_time || null,
        item.end_time || null,
        item.duration_minutes || null,
        item.item_type || 'activity',
        item.status || 'planned',
        item.cost || null,
        item.notes || null,
        item.booking_reference || null,
      ]
    );
    return result.rows[0];
  }

  async updateItem(itemId: string, itemData: Partial<ItineraryItem>): Promise<ItineraryItem | null> {
    const fields: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    const allowedFields = [
      'place_id', 'order_index', 'title', 'description', 'start_time',
      'end_time', 'duration_minutes', 'item_type', 'status', 'cost', 'notes', 'booking_reference'
    ];

    for (const field of allowedFields) {
      if (itemData[field as keyof ItineraryItem] !== undefined) {
        fields.push(`${field} = $${paramIndex}`);
        values.push(itemData[field as keyof ItineraryItem]);
        paramIndex++;
      }
    }

    if (fields.length === 0) {
      const result = await query<ItineraryItem>('SELECT * FROM itinerary_items WHERE id = $1', [itemId]);
      return result.rows[0] || null;
    }

    values.push(itemId);
    const result = await query<ItineraryItem>(
      `UPDATE itinerary_items SET ${fields.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      values
    );
    return result.rows[0] || null;
  }

  async removeItem(itemId: string): Promise<boolean> {
    const result = await query('DELETE FROM itinerary_items WHERE id = $1', [itemId]);
    return (result.rowCount ?? 0) > 0;
  }

  async getOrCreateItineraryByDay(tripId: string, dayNumber: number): Promise<Itinerary> {
    // Buscar itinerary existente
    const existing = await query<Itinerary>(
      'SELECT * FROM itineraries WHERE trip_id = $1 AND day_number = $2',
      [tripId, dayNumber]
    );

    if (existing.rows.length > 0) {
      return existing.rows[0];
    }

    // Criar novo itinerary se não existir
    const result = await query<Itinerary>(
      `INSERT INTO itineraries (trip_id, day_number, date, title)
       VALUES ($1, $2, NOW() + INTERVAL '${dayNumber - 1} days', $3)
       RETURNING *`,
      [tripId, dayNumber, `Day ${dayNumber}`]
    );
    return result.rows[0];
  }
}

export const itinerariesService = new ItinerariesService();
