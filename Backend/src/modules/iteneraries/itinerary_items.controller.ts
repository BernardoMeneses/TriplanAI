import { Request, Response } from 'express';
import { ItineraryItemsService } from './itinerary_items.service';

const itineraryItemsService = new ItineraryItemsService();

export class ItineraryItemsController {
  async createItem(req: Request, res: Response) {
    try {
      const item = await itineraryItemsService.createItineraryItem(req.body);
      res.status(201).json(item);
    } catch (error) {
      console.error('Error creating itinerary item:', error);
      res.status(500).json({ error: 'Failed to create itinerary item' });
    }
  }

  async getItemsByDay(req: Request, res: Response) {
    try {
      const { itineraryId } = req.params;
      const items = await itineraryItemsService.getItineraryItemsByDay(itineraryId);
      res.json(items);
    } catch (error) {
      console.error('Error fetching itinerary items:', error);
      res.status(500).json({ error: 'Failed to fetch itinerary items' });
    }
  }

  async getItemById(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const item = await itineraryItemsService.getItineraryItemById(id);
      
      if (!item) {
        return res.status(404).json({ error: 'Itinerary item not found' });
      }
      
      res.json(item);
    } catch (error) {
      console.error('Error fetching itinerary item:', error);
      res.status(500).json({ error: 'Failed to fetch itinerary item' });
    }
  }

  async updateItem(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const item = await itineraryItemsService.updateItineraryItem(id, req.body);
      res.json(item);
    } catch (error) {
      console.error('Error updating itinerary item:', error);
      res.status(500).json({ error: 'Failed to update itinerary item' });
    }
  }

  async deleteItem(req: Request, res: Response) {
    try {
      const { id } = req.params;
      await itineraryItemsService.deleteItineraryItem(id);
      res.status(204).send();
    } catch (error) {
      console.error('Error deleting itinerary item:', error);
      res.status(500).json({ error: 'Failed to delete itinerary item' });
    }
  }

  async reorderItems(req: Request, res: Response) {
    try {
      const { itineraryId } = req.params;
      const { itemIds } = req.body;
      await itineraryItemsService.reorderItems(itineraryId, itemIds);
      res.status(200).json({ message: 'Items reordered successfully' });
    } catch (error) {
      console.error('Error reordering items:', error);
      res.status(500).json({ error: 'Failed to reorder items' });
    }
  }
}
