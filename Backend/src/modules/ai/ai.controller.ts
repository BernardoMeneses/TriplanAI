import { Router, Request, Response } from 'express';
import { aiService } from './ai.service';
import { authenticate } from '../../middlewares';

const router = Router();

// POST /api/ai/suggestions - Gerar sugestões de lugares para chat AI
router.post('/suggestions', authenticate, async (req: Request, res: Response) => {
  try {
    const { query, location, dayNumber, conversationId, tripId } = req.body;
    const userId = req.user?.id;
    
    if (!query) {
      return res.status(400).json({ error: 'Query é obrigatória' });
    }

    const result = await aiService.generatePlaceSuggestions({
      query,
      location: location || '',
      dayNumber: dayNumber || 1,
    });
    
    // Save to conversation history
    let currentConversationId = conversationId;
    
    if (!currentConversationId && userId) {
      // Create new conversation if none exists
      const newConversation = await aiService.createConversation(
        userId, 
        tripId || null, 
        `Day ${dayNumber || 1} suggestions`
      );
      currentConversationId = newConversation.id;
    }
    
    if (currentConversationId) {
      await aiService.addMessageToConversation(currentConversationId, 'user', query);
      await aiService.addMessageToConversation(currentConversationId, 'assistant', result.response);
      (result as any).conversationId = currentConversationId;
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error in AI suggestions:', error);
    res.status(500).json({ error: 'Erro ao gerar sugestões' });
  }
});

// POST /api/ai/trip-suggestions - Gerar sugestões de viagem com IA
router.post('/trip-suggestions', async (req: Request, res: Response) => {
  try {
    const { interests, budget, duration, travelStyle } = req.body;
    
    if (!interests || !Array.isArray(interests) || interests.length === 0) {
      return res.status(400).json({ error: 'Lista de interesses é obrigatória' });
    }

    const suggestions = await aiService.generateTripSuggestions({
      interests,
      budget,
      duration,
      travelStyle
    });
    res.json(suggestions);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao gerar sugestões' });
  }
});

// POST /api/ai/itinerary - Gerar itinerário automático com IA
router.post('/itinerary', async (req: Request, res: Response) => {
  try {
    const { destination, startDate, endDate, interests, pace } = req.body;
    
    if (!destination || !startDate || !endDate || !interests) {
      return res.status(400).json({ 
        error: 'Destino, data de início, data de fim e interesses são obrigatórios' 
      });
    }

    const itinerary = await aiService.generateItinerary({
      destination,
      startDate,
      endDate,
      interests,
      pace
    });
    res.json(itinerary);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao gerar itinerário' });
  }
});

// POST /api/ai/chat - Chat com assistente de viagem IA
router.post('/chat', async (req: Request, res: Response) => {
  try {
    const { messages, context } = req.body;
    
    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: 'Mensagens são obrigatórias' });
    }

    const response = await aiService.chat(messages, context);
    res.json({ response });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao processar mensagem' });
  }
});

// POST /api/ai/recommendations - Obter recomendações de locais com IA
router.post('/recommendations', async (req: Request, res: Response) => {
  try {
    const { destination, interests } = req.body;
    
    if (!destination || !interests || !Array.isArray(interests)) {
      return res.status(400).json({ error: 'Destino e interesses são obrigatórios' });
    }

    const recommendations = await aiService.getPlaceRecommendations(destination, interests);
    res.json(recommendations);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao obter recomendações' });
  }
});

// POST /api/ai/translate - Traduzir texto
router.post('/translate', async (req: Request, res: Response) => {
  try {
    const { text, targetLanguage } = req.body;
    
    if (!text || !targetLanguage) {
      return res.status(400).json({ error: 'Texto e idioma de destino são obrigatórios' });
    }

    const translated = await aiService.translateText(text, targetLanguage);
    res.json({ translated });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao traduzir texto' });
  }
});

// POST /api/ai/analyze-sentiment - Analisar sentimento de reviews
router.post('/analyze-sentiment', async (req: Request, res: Response) => {
  try {
    const { reviews } = req.body;
    
    if (!reviews || !Array.isArray(reviews) || reviews.length === 0) {
      return res.status(400).json({ error: 'Lista de reviews é obrigatória' });
    }

    const analysis = await aiService.analyzeTripSentiment(reviews);
    res.json(analysis);
  } catch (error) {
    res.status(500).json({ error: 'Erro ao analisar sentimento' });
  }
});

// GET /api/ai/place-suggestions - Obter sugestões de lugares para visitar
router.get('/place-suggestions', async (req: Request, res: Response) => {
  try {
    const { city, country, dayNumber } = req.query;
    
    if (!city && !country) {
      return res.status(400).json({ error: 'Cidade ou país são obrigatórios' });
    }

    const suggestions = await aiService.getPlaceSuggestions(
      (city as string) || '',
      (country as string) || '',
      dayNumber ? parseInt(dayNumber as string) : undefined
    );
    res.json(suggestions);
  } catch (error) {
    console.error('Erro ao obter sugestões:', error);
    res.status(500).json({ error: 'Erro ao obter sugestões de lugares' });
  }
});

// GET /api/ai/conversations - Obter conversas do utilizador
router.get('/conversations', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;
    const tripId = req.query.tripId as string;

    if (!userId) {
      return res.status(401).json({ error: 'Utilizador não autenticado' });
    }

    const conversations = await aiService.getConversations(userId, tripId);
    res.json(conversations);
  } catch (error) {
    console.error('Erro ao buscar conversas:', error);
    res.status(500).json({ error: 'Erro ao buscar conversas' });
  }
});

// GET /api/ai/conversations/:id - Obter conversa específica com mensagens
router.get('/conversations/:id', authenticate, async (req: Request, res: Response) => {
  try {
    const conversationId = req.params.id;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ error: 'Utilizador não autenticado' });
    }

    const conversation = await aiService.getConversationWithMessages(conversationId, userId);
    
    if (!conversation) {
      return res.status(404).json({ error: 'Conversa não encontrada' });
    }

    res.json(conversation);
  } catch (error) {
    console.error('Erro ao buscar conversa:', error);
    res.status(500).json({ error: 'Erro ao buscar conversa' });
  }
});

// DELETE /api/ai/conversations/:id - Eliminar conversa
router.delete('/conversations/:id', authenticate, async (req: Request, res: Response) => {
  try {
    const conversationId = req.params.id;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ error: 'Utilizador não autenticado' });
    }

    await aiService.deleteConversation(conversationId, userId);
    res.json({ message: 'Conversa eliminada com sucesso' });
  } catch (error) {
    console.error('Erro ao eliminar conversa:', error);
    res.status(500).json({ error: 'Erro ao eliminar conversa' });
  }
});

export const aiController = router;
