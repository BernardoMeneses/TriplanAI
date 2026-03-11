import { Router, Request, Response } from 'express';
import { notesService } from './notes.service';

const router = Router();

/**
 * GET /api/notes/:tripId
 * List all notes for a trip (user must own the trip)
 */
router.get('/:tripId', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;
    const { tripId } = req.params;
    const notes = await notesService.getNotesByTrip(userId, tripId);
    res.json(notes);
  } catch (error) {
    console.error('Error fetching notes:', error);
    res.status(500).json({ error: 'Error fetching notes' });
  }
});

/**
 * POST /api/notes
 * Create a new note
 * Body: { tripId, title, body }
 */
router.post('/', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;
    const { tripId, title, body } = req.body;

    if (!tripId) {
      return res.status(400).json({ error: 'tripId is required' });
    }

    const note = await notesService.createNote(userId, tripId, title ?? '', body ?? '');
    res.status(201).json(note);
  } catch (error: any) {
    if (error.message?.includes('access denied')) {
      return res.status(403).json({ error: 'Access denied' });
    }
    console.error('Error creating note:', error);
    res.status(500).json({ error: 'Error creating note' });
  }
});

/**
 * PUT /api/notes/:id
 * Update a note
 * Body: { title, body }
 */
router.put('/:id', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;
    const { id } = req.params;
    const { title, body } = req.body;

    const note = await notesService.updateNote(userId, id, title ?? '', body ?? '');
    res.json(note);
  } catch (error: any) {
    if (error.message?.includes('access denied')) {
      return res.status(403).json({ error: 'Access denied' });
    }
    console.error('Error updating note:', error);
    res.status(500).json({ error: 'Error updating note' });
  }
});

/**
 * DELETE /api/notes/:id
 * Delete a note
 */
router.delete('/:id', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;
    const { id } = req.params;
    await notesService.deleteNote(userId, id);
    res.status(204).send();
  } catch (error: any) {
    if (error.message?.includes('access denied')) {
      return res.status(403).json({ error: 'Access denied' });
    }
    console.error('Error deleting note:', error);
    res.status(500).json({ error: 'Error deleting note' });
  }
});

export { router as notesController };
