import { query } from '../../config/database';

export interface Note {
  id: string;
  trip_id: string;
  user_id: string;
  title: string;
  body: string;
  created_at: Date;
  updated_at: Date;
}

export class NotesService {
  async getNotesByTrip(userId: string, tripId: string): Promise<Note[]> {
    // Return notes if user owns the trip OR is a member
    const result = await query<Note>(
      `SELECT n.* FROM trip_notes n
       INNER JOIN trips t ON t.id = n.trip_id
       WHERE n.trip_id = $1
         AND (t.user_id = $2
              OR EXISTS (
                SELECT 1 FROM trip_members tm WHERE tm.trip_id = $1 AND tm.user_id = $2
              ))
       ORDER BY n.created_at DESC`,
      [tripId, userId]
    );
    return result.rows;
  }

  async createNote(userId: string, tripId: string, title: string, body: string): Promise<Note> {
    // Verify the trip belongs to this user OR user is a member
    const tripCheck = await query(
      `SELECT 1 FROM trips t
       WHERE t.id = $1
         AND (t.user_id = $2
              OR EXISTS (
                SELECT 1 FROM trip_members tm WHERE tm.trip_id = $1 AND tm.user_id = $2
              ))`,
      [tripId, userId]
    );
    if (tripCheck.rowCount === 0) {
      throw new Error('Trip not found or access denied');
    }

    const result = await query<Note>(
      `INSERT INTO trip_notes (trip_id, user_id, title, body)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [tripId, userId, title || '', body || '']
    );
    return result.rows[0];
  }

  async updateNote(userId: string, noteId: string, title: string, body: string): Promise<Note> {
    const result = await query<Note>(
      `UPDATE trip_notes
       SET title = $1, body = $2, updated_at = NOW()
       WHERE id = $3 AND user_id = $4
       RETURNING *`,
      [title || '', body || '', noteId, userId]
    );
    if (result.rowCount === 0) {
      throw new Error('Note not found or access denied');
    }
    return result.rows[0];
  }

  async deleteNote(userId: string, noteId: string): Promise<void> {
    const result = await query(
      'DELETE FROM trip_notes WHERE id = $1 AND user_id = $2',
      [noteId, userId]
    );
    if (result.rowCount === 0) {
      throw new Error('Note not found or access denied');
    }
  }
}

export const notesService = new NotesService();
