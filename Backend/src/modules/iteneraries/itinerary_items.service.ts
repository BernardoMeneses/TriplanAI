import { query } from '../../config/database';
import { mapsService } from '../maps/maps.service';
import { routesService } from '../routes/routes.service';

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
  item_type: string;
  status: string;
  cost?: number;
  notes?: string;
  booking_reference?: string;
  created_at: Date;
  updated_at: Date;
  // Distance tracking fields
  distance_from_previous_meters?: number;
  distance_from_previous_text?: string;
  travel_time_from_previous_seconds?: number;
  travel_time_from_previous_text?: string;
  transport_mode?: string; // walking, driving, transit
  is_starting_point?: boolean;
  // Dados do place associado
  place?: {
    id: string;
    name: string;
    google_place_id?: string;
    address?: string;
    city?: string;
    country?: string;
    latitude?: number;
    longitude?: number;
    rating?: number;
    images?: string[];
  };
}

export class ItineraryItemsService {
  async createItineraryItem(data: {
    itineraryId: string;
    placeId?: string;
    googlePlaceId?: string;
    orderIndex: number;
    title: string;
    description?: string;
    startTime?: string;
    endTime?: string;
    durationMinutes?: number;
    itemType: string;
    status?: string;
    cost?: number;
    notes?: string;
  }): Promise<ItineraryItem> {
    let placeId = data.placeId;

    // Se não tem placeId mas tem googlePlaceId, criar/buscar o place primeiro
    if (!placeId && data.googlePlaceId) {
      const existingPlace = await query(
        'SELECT id FROM places WHERE google_place_id = $1',
        [data.googlePlaceId]
      );

      if (existingPlace.rows.length > 0) {
        placeId = existingPlace.rows[0].id;
      } else {
        // Buscar trip_id através do itinerary
        const itineraryResult = await query(
          'SELECT trip_id FROM itineraries WHERE id = $1',
          [data.itineraryId]
        );
        
        if (itineraryResult.rows.length === 0) {
          throw new Error('Itinerary not found');
        }
        
        const tripId = itineraryResult.rows[0].trip_id;
        
        // Buscar detalhes completos do Google Places API
        const placeDetails = await mapsService.getPlaceDetails(data.googlePlaceId);
        
        if (placeDetails) {
          // Determinar place_type baseado nos types do Google
          let placeType = 'attraction'; // default
          if (placeDetails.types.includes('museum')) placeType = 'museum';
          else if (placeDetails.types.includes('park')) placeType = 'park';
          else if (placeDetails.types.includes('restaurant')) placeType = 'restaurant';
          else if (placeDetails.types.includes('lodging') || placeDetails.types.includes('hotel')) placeType = 'hotel';
          else if (placeDetails.types.includes('shopping_mall')) placeType = 'shopping';
          else if (placeDetails.types.includes('tourist_attraction')) placeType = 'attraction';
          
          // Estimar duração baseada no tipo de lugar
          let estimatedDuration = data.durationMinutes;
          if (!estimatedDuration) {
            if (placeType === 'museum') estimatedDuration = 120; // 2h
            else if (placeType === 'park') estimatedDuration = 90; // 1.5h
            else if (placeType === 'restaurant') estimatedDuration = 90; // 1.5h
            else if (placeType === 'shopping') estimatedDuration = 180; // 3h
            else estimatedDuration = 60; // 1h default
          }
          
          // Criar novo place com todos os detalhes
          const contactInfo = {
            phone: placeDetails.phoneNumber || null,
            website: placeDetails.website || null,
          };
          
          const newPlace = await query(
            `INSERT INTO places (
              trip_id, name, google_place_id, description, address, 
              city, country, latitude, longitude, rating, images, place_type, opening_hours, price_level, contact_info
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
            RETURNING id`,
            [
              tripId,
              placeDetails.name,
              data.googlePlaceId,
              data.description || placeDetails.formattedAddress,
              placeDetails.formattedAddress,
              null, // city pode ser extraído depois se necessário
              null, // country pode ser extraído depois se necessário
              placeDetails.location.lat,
              placeDetails.location.lng,
              placeDetails.rating || null,
              placeDetails.photos ? JSON.stringify(placeDetails.photos) : '[]',
              placeType,
              placeDetails.openingHours ? JSON.stringify(placeDetails.openingHours) : null,
              placeDetails.priceLevel || null,
              JSON.stringify(contactInfo),
            ]

          );
          placeId = newPlace.rows[0].id;
          
          // Usar duração estimada se não foi fornecida
          if (!data.durationMinutes) {
            data.durationMinutes = estimatedDuration;
          }
        } else {
          // Fallback: criar place básico se não conseguir buscar detalhes
          const newPlace = await query(
            `INSERT INTO places (name, google_place_id, description)
             VALUES ($1, $2, $3)
             RETURNING id`,
            [data.title, data.googlePlaceId, data.description || null]
          );
          placeId = newPlace.rows[0].id;
        }
      }
    }

    // Calcular start_time default se não fornecido (9h + 3h por atividade anterior)
    let startTime = data.startTime;
    if (!startTime) {
      const baseHour = 9; // Começar às 9h
      const hoursToAdd = data.orderIndex * 3; // 3h entre atividades
      const calculatedHour = baseHour + hoursToAdd;
      startTime = `${String(calculatedHour).padStart(2, '0')}:00`;
    }
    
    // Calcular end_time se duration_minutes foi fornecido
    let endTime = data.endTime;
    if (!endTime && data.durationMinutes && startTime) {
      const [hours, minutes] = startTime.split(':').map(Number);
      const totalMinutes = hours * 60 + minutes + data.durationMinutes;
      const endHours = Math.floor(totalMinutes / 60) % 24;
      const endMinutes = totalMinutes % 60;
      endTime = `${String(endHours).padStart(2, '0')}:${String(endMinutes).padStart(2, '0')}`;
    }
    
    const result = await query<ItineraryItem>(
      `INSERT INTO itinerary_items (
        itinerary_id, place_id, order_index, title, description,
        start_time, end_time, duration_minutes, item_type, status, cost, notes, is_starting_point
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      RETURNING *`,
      [
        data.itineraryId,
        placeId || null,
        data.orderIndex,
        data.title,
        data.description || null,
        startTime,
        endTime,
        data.durationMinutes || 60, // Default 1h
        data.itemType,
        data.status || 'planned',
        data.cost || null,
        data.notes || null,
        data.orderIndex === 0, // First item is starting point
      ]
    );
    
    // Calculate distances if this is not the first item
    if (data.orderIndex > 0) {
      await this.calculateDistancesForItem(data.itineraryId, result.rows[0].id);
      
      // Recalculate times starting from the previous item to include travel time
      // This ensures the newly created item gets the correct start time based on:
      // previous_start + previous_duration + travel_time
      await this.recalculateTimesFromItem(data.itineraryId, data.orderIndex - 1);
    } else {
      // If this is the first item, just recalculate subsequent items
      await this.recalculateTimesFromItem(data.itineraryId, data.orderIndex);
    }
    
    // Fetch the updated item to return with correct times
    const updatedResult = await query<ItineraryItem>(
      `SELECT * FROM itinerary_items WHERE id = $1`,
      [result.rows[0].id]
    );
    
    return updatedResult.rows[0];
  }

  async getItineraryItemsByDay(itineraryId: string): Promise<ItineraryItem[]> {
    const result = await query<ItineraryItem>(
      `SELECT 
        ii.*,
        json_build_object(
          'id', p.id,
          'name', p.name,
          'google_place_id', p.google_place_id,
          'address', p.address,
          'city', p.city,
          'country', p.country,
          'latitude', p.latitude,
          'longitude', p.longitude,
          'rating', p.rating,
          'images', p.images,
          'place_type', p.place_type,
          'opening_hours', p.opening_hours,
          'price_level', p.price_level,
          'contact_info', p.contact_info
        ) as place
      FROM itinerary_items ii
      LEFT JOIN places p ON ii.place_id = p.id
      WHERE ii.itinerary_id = $1
      ORDER BY ii.order_index ASC`,
      [itineraryId]
    );
    
    // Parse images se for string
    const items = result.rows.map(item => {
      if (item.place && item.place.images && typeof item.place.images === 'string') {
        try {
          item.place.images = JSON.parse(item.place.images);
        } catch (e) {
          item.place.images = [];
        }
      }
      return item;
    });
    
    return items;
  }

  async getItineraryItemById(id: string): Promise<ItineraryItem | null> {
    const result = await query<ItineraryItem>(
      `SELECT 
        ii.*,
        json_build_object(
          'id', p.id,
          'name', p.name,
          'google_place_id', p.google_place_id,
          'address', p.address,
          'city', p.city,
          'country', p.country,
          'latitude', p.latitude,
          'longitude', p.longitude,
          'rating', p.rating,
          'images', p.images,
          'place_type', p.place_type,
          'opening_hours', p.opening_hours,
          'price_level', p.price_level,
          'contact_info', p.contact_info
        ) as place
      FROM itinerary_items ii
      LEFT JOIN places p ON ii.place_id = p.id
      WHERE ii.id = $1`,
      [id]
    );
    return result.rows[0] || null;
  }

  async updateItineraryItem(
    id: string,
    data: {
      itineraryId?: string;
      orderIndex?: number;
      title?: string;
      description?: string;
      startTime?: string;
      endTime?: string;
      durationMinutes?: number;
      status?: string;
      cost?: number;
      notes?: string;
      transportMode?: string;
    }
  ): Promise<ItineraryItem> {
    const updates: string[] = [];
    const values: any[] = [];
    let paramCount = 1;

    if (data.itineraryId !== undefined) {
      updates.push(`itinerary_id = $${paramCount++}`);
      values.push(data.itineraryId);
    }
    if (data.orderIndex !== undefined) {
      updates.push(`order_index = $${paramCount++}`);
      values.push(data.orderIndex);
    }
    if (data.title !== undefined) {
      updates.push(`title = $${paramCount++}`);
      values.push(data.title);
    }
    if (data.description !== undefined) {
      updates.push(`description = $${paramCount++}`);
      values.push(data.description);
    }
    if (data.startTime !== undefined) {
      updates.push(`start_time = $${paramCount++}`);
      values.push(data.startTime);
    }
    if (data.endTime !== undefined) {
      updates.push(`end_time = $${paramCount++}`);
      values.push(data.endTime);
    }
    if (data.durationMinutes !== undefined) {
      updates.push(`duration_minutes = $${paramCount++}`);
      values.push(data.durationMinutes);
    }
    if (data.status !== undefined) {
      updates.push(`status = $${paramCount++}`);
      values.push(data.status);
    }
    if (data.cost !== undefined) {
      updates.push(`cost = $${paramCount++}`);
      values.push(data.cost);
    }
    if (data.notes !== undefined) {
      updates.push(`notes = $${paramCount++}`);
      values.push(data.notes);
    }
    if (data.transportMode !== undefined) {
      updates.push(`transport_mode = $${paramCount++}`);
      values.push(data.transportMode);
    }

    if (updates.length === 0) {
      const item = await this.getItineraryItemById(id);
      if (!item) {
        throw new Error('Itinerary item not found');
      }
      return item;
    }

    updates.push('updated_at = CURRENT_TIMESTAMP');
    values.push(id);

    const result = await query<ItineraryItem>(
      `UPDATE itinerary_items
       SET ${updates.join(', ')}
       WHERE id = $${paramCount}
       RETURNING *`,
      values
    );
    
    const updatedItem = result.rows[0];
    
    // Se transport_mode foi atualizado, recalcular distâncias e tempos com o novo modo
    if (data.transportMode !== undefined && updatedItem.order_index > 0) {
      await this.calculateDistancesForItem(updatedItem.itinerary_id, updatedItem.id);
      // Buscar item novamente após recalcular para obter os valores atualizados
      const refreshedItem = await this.getItineraryItemById(updatedItem.id);
      if (refreshedItem) {
        return refreshedItem;
      }
    }
    
    // Se start_time ou duration_minutes foram atualizados, recalcular horários dos próximos itens
    if (data.startTime !== undefined || data.durationMinutes !== undefined) {
      await this.recalculateTimesFromItem(updatedItem.itinerary_id, updatedItem.order_index);
    }
    
    return updatedItem;
  }

  async deleteItineraryItem(id: string): Promise<void> {
    await query('DELETE FROM itinerary_items WHERE id = $1', [id]);
  }

  async reorderItems(itineraryId: string, itemIds: string[]): Promise<void> {
    // Atualizar ordem de múltiplos items de uma vez
    for (let i = 0; i < itemIds.length; i++) {
      await query(
        `UPDATE itinerary_items 
         SET order_index = $1, is_starting_point = $2 
         WHERE id = $3 AND itinerary_id = $4`,
        [i, i === 0, itemIds[i], itineraryId]
      );
    }
    
    // Recalcular distâncias para todos os items
    for (let i = 1; i < itemIds.length; i++) {
      await this.calculateDistancesForItem(itineraryId, itemIds[i]);
    }
    
    // Recalcular todos os horários desde o início para manter consistência
    await this.recalculateTimesFromItem(itineraryId, 0);
  }

  /**
   * Calculate distance and travel time from previous item
   */
  private async calculateDistancesForItem(itineraryId: string, itemId: string): Promise<void> {
    // Get current item and previous item
    const itemResult = await query(
      `SELECT ii.*, p.latitude, p.longitude, p.city
       FROM itinerary_items ii
       LEFT JOIN places p ON ii.place_id = p.id
       WHERE ii.id = $1`,
      [itemId]
    );

    if (itemResult.rows.length === 0) return;
    const currentItem = itemResult.rows[0];

    // Get previous item
    const previousResult = await query(
      `SELECT ii.*, p.latitude, p.longitude, p.city
       FROM itinerary_items ii
       LEFT JOIN places p ON ii.place_id = p.id
       WHERE ii.itinerary_id = $1 AND ii.order_index = $2`,
      [itineraryId, currentItem.order_index - 1]
    );

    if (previousResult.rows.length === 0) return;
    const previousItem = previousResult.rows[0];

    // Check if both items have coordinates
    if (!currentItem.latitude || !currentItem.longitude || 
        !previousItem.latitude || !previousItem.longitude) {
      return;
    }

    try {
      // Check if item already has a transport mode set by user
      let transportMode = currentItem.transport_mode;
      
      // If no transport mode is set, determine it automatically
      if (!transportMode) {
        // Get trip information to determine city type
        const tripResult = await query(
          `SELECT t.destination_city, t.destination_country
           FROM trips t
           JOIN itineraries i ON i.trip_id = t.id
           WHERE i.id = $1`,
          [itineraryId]
        );

        const isBigCity = tripResult.rows.length > 0 ? 
          this.isBigCity(tripResult.rows[0].destination_city, tripResult.rows[0].destination_country) : false;

        // First, calculate with driving to get initial duration for decision
        const initialResult = await routesService.getDistance(
          { latitude: previousItem.latitude, longitude: previousItem.longitude },
          { latitude: currentItem.latitude, longitude: currentItem.longitude },
          'driving'
        );

        if (initialResult) {
          // Determine transport mode based on travel time and city type
          transportMode = this.determineTransportMode(
            initialResult.duration,
            isBigCity
          );
        }
      }

      // Calculate distance and time with the determined or user-selected transport mode
      const finalResult = await routesService.getDistance(
        { latitude: previousItem.latitude, longitude: previousItem.longitude },
        { latitude: currentItem.latitude, longitude: currentItem.longitude },
        transportMode as 'walking' | 'driving' | 'transit'
      );

      if (finalResult) {
        // Update item with distance information
        await query(
          `UPDATE itinerary_items
           SET distance_from_previous_meters = $1,
               distance_from_previous_text = $2,
               travel_time_from_previous_seconds = $3,
               travel_time_from_previous_text = $4,
               transport_mode = $5
           WHERE id = $6`,
          [
            finalResult.distance,
            finalResult.distanceText,
            finalResult.duration,
            finalResult.durationText,
            transportMode,
            itemId
          ]
        );
      }
    } catch (error) {
      console.error('Error calculating distance:', error);
      // Don't fail the whole operation if distance calculation fails
    }
  }

  /**
   * Determine best transport mode based on travel time and city type
   * Rules:
   * - Less than 10 minutes: walking
   * - More than 10 minutes in big city: transit (public transport)
   * - More than 10 minutes in rural/small city: driving (car)
   */
  private determineTransportMode(travelTimeSeconds: number, isBigCity: boolean): string {
    const travelTimeMinutes = travelTimeSeconds / 60;

    // Less than 10 minutes -> walking
    if (travelTimeMinutes < 10) {
      return 'walking';
    }

    // More than 10 minutes -> depends on city type
    if (isBigCity) {
      return 'transit'; // Public transport in big cities
    } else {
      return 'driving'; // Car in rural/small cities
    }
  }

  /**
   * Check if a city is considered a "big city" for transport purposes
   */
  private isBigCity(city: string, country: string): boolean {
    const bigCities: { [key: string]: string[] } = {
      'Portugal': ['Lisboa', 'Lisbon', 'Porto', 'Oporto'],
      'Spain': ['Madrid', 'Barcelona', 'Valencia', 'Seville', 'Sevilla', 'Bilbao'],
      'France': ['Paris', 'Lyon', 'Marseille', 'Toulouse', 'Nice'],
      'Italy': ['Rome', 'Roma', 'Milan', 'Milano', 'Naples', 'Napoli', 'Turin', 'Torino', 'Florence', 'Firenze'],
      'Germany': ['Berlin', 'Munich', 'München', 'Hamburg', 'Cologne', 'Köln', 'Frankfurt'],
      'United Kingdom': ['London', 'Manchester', 'Birmingham', 'Glasgow', 'Liverpool', 'Edinburgh'],
      'United States': ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Francisco', 'Washington'],
      'Brazil': ['São Paulo', 'Rio de Janeiro', 'Brasília', 'Salvador', 'Fortaleza', 'Belo Horizonte'],
      'Japan': ['Tokyo', 'Osaka', 'Yokohama', 'Nagoya', 'Sapporo', 'Fukuoka', 'Kyoto'],
      'China': ['Beijing', 'Shanghai', 'Guangzhou', 'Shenzhen', 'Chengdu', 'Hangzhou'],
      'India': ['Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai', 'Kolkata'],
    };

    // Normalize city name for comparison
    const normalizedCity = city.toLowerCase().trim();
    
    // Check if country exists in our list
    const countryCities = bigCities[country];
    if (countryCities) {
      return countryCities.some(bigCity => 
        bigCity.toLowerCase() === normalizedCity
      );
    }

    // If country not in list, check all cities across all countries
    for (const cities of Object.values(bigCities)) {
      if (cities.some(bigCity => bigCity.toLowerCase() === normalizedCity)) {
        return true;
      }
    }

    return false;
  }

  /**
   * Recalculate all distances for an itinerary
   */
  async recalculateDistances(itineraryId: string): Promise<void> {
    const items = await this.getItineraryItemsByDay(itineraryId);
    
    for (let i = 1; i < items.length; i++) {
      await this.calculateDistancesForItem(itineraryId, items[i].id);
    }
  }

  /**
   * Calculate next start time based on previous item
   * The formula is: next_start_time = previous_start_time + previous_duration + travel_time
   */
  private calculateNextStartTime(
    previousStartTime: string,
    previousDuration: number,
    travelTimeSeconds: number = 0
  ): string {
    try {
      const [hours, minutes] = previousStartTime.split(':').map(Number);
      let totalMinutes = hours * 60 + minutes;
      
      // Add duration of previous item
      totalMinutes += previousDuration;
      
      // Add travel time to next item (convert seconds to minutes)
      const travelTimeMinutes = Math.ceil(travelTimeSeconds / 60);
      totalMinutes += travelTimeMinutes;
      
      const newHours = Math.floor(totalMinutes / 60) % 24;
      const newMinutes = totalMinutes % 60;
      
      return `${String(newHours).padStart(2, '0')}:${String(newMinutes).padStart(2, '0')}:00`;
    } catch (error) {
      console.error('Error calculating next start time:', error);
      return '09:00:00';
    }
  }

  /**
   * Recalculate start times for all items after a given index
   */
  private async recalculateTimesFromItem(itineraryId: string, fromIndex: number): Promise<void> {
    const items = await this.getItineraryItemsByDay(itineraryId);
    
    // Se fromIndex é 0, forçar o primeiro item a ter horário base de 09:00
    if (fromIndex === 0 && items.length > 0) {
      const firstItem = items[0];
      const baseStartTime = '09:00:00';
      
      // Calcular end_time do primeiro item
      let endTime: string | undefined;
      if (firstItem.duration_minutes) {
        const totalMinutes = 9 * 60 + firstItem.duration_minutes; // 09:00 + duração
        const endHours = Math.floor(totalMinutes / 60) % 24;
        const endMinutes = totalMinutes % 60;
        endTime = `${String(endHours).padStart(2, '0')}:${String(endMinutes).padStart(2, '0')}:00`;
      }
      
      await query(
        `UPDATE itinerary_items
         SET start_time = $1, end_time = $2
         WHERE id = $3`,
        [baseStartTime, endTime, firstItem.id]
      );
      
      // Atualizar local copy
      items[0].start_time = baseStartTime;
      items[0].end_time = endTime;
    }
    
    // Start from the item after the updated one
    for (let i = fromIndex + 1; i < items.length; i++) {
      const previousItem = items[i - 1];
      const currentItem = items[i];
      
      if (!previousItem.start_time) continue;
      
      // Calculate next start time: previous start + previous duration + travel time
      const newStartTime = this.calculateNextStartTime(
        previousItem.start_time,
        previousItem.duration_minutes || 60,
        currentItem.travel_time_from_previous_seconds || 0
      );
      
      // Calculate end_time based on duration
      let endTime: string | undefined;
      if (currentItem.duration_minutes) {
        const [hours, minutes] = newStartTime.split(':').map(Number);
        const totalMinutes = hours * 60 + minutes + currentItem.duration_minutes;
        const endHours = Math.floor(totalMinutes / 60) % 24;
        const endMinutes = totalMinutes % 60;
        endTime = `${String(endHours).padStart(2, '0')}:${String(endMinutes).padStart(2, '0')}:00`;
      }
      
      // Update the item with new times
      await query(
        `UPDATE itinerary_items
         SET start_time = $1, end_time = $2
         WHERE id = $3`,
        [newStartTime, endTime, currentItem.id]
      );
      
      // Update local copy for next iteration
      items[i].start_time = newStartTime;
      items[i].end_time = endTime;
    }
  }
}
