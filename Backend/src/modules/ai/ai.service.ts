import OpenAI from 'openai';
import { query } from '../../config/database';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';

export interface TripSuggestion {
  destination: string;
  description: string;
  activities: string[];
  bestTimeToVisit: string;
  estimatedBudget: {
    min: number;
    max: number;
    currency: string;
  };
}

export interface ItinerarySuggestion {
  day: number;
  activities: {
    time: string;
    activity: string;
    location: string;
    duration: string;
    tips?: string;
  }[];
}

export interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

export interface PlaceRecommendation {
  name: string;
  description: string;
  category: string;
  estimatedDuration?: string;
  priceLevel?: string;
}

export class AIService {
  private systemPrompt = `Você é um assistente de viagem especializado chamado TriplanAI. 
Você ajuda utilizadores a planear viagens, sugere destinos, cria itinerários e fornece dicas de viagem.
Responda sempre em português de Portugal (pt-PT).
Seja amigável, informativo e prático nas suas respostas.
Quando sugerir lugares, inclua informações úteis como horários, preços estimados e dicas práticas.`;

  async generatePlaceSuggestions(params: {
    query: string;
    location: string;
    dayNumber: number;
  }): Promise<{ response: string; places: any[] }> {
    const prompt = `O utilizador está a planear o dia ${params.dayNumber} em ${params.location}.
Pergunta: "${params.query}"

Responde com uma mensagem amigável e sugere 4-5 lugares relevantes.

Responde em formato JSON com este schema:
{
  "response": "mensagem amigável respondendo ao utilizador (ex: 'Great! Here are my top five-star hotel picks near Marina Bay:')",
  "places": [{
    "name": "nome do lugar",
    "category": "categoria (ex: Accommodation, Restaurant, Museum, Park, Shopping, Activities & Experiences, Nature & Outdoor)",
    "placeId": "deixa vazio por agora, será preenchido depois",
    "description": "breve descrição do lugar"
  }]
}

Responde APENAS com o JSON, sem texto adicional.`;

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: 'system', content: this.systemPrompt },
          { role: 'user', content: prompt }
        ],
        temperature: 0.7,
        response_format: { type: 'json_object' }
      });

      const content = response.choices[0]?.message?.content;
      if (!content) {
        return {
          response: 'Desculpa, tive dificuldade em processar isso. Podes tentar reformular?',
          places: []
        };
      }

      const parsed = JSON.parse(content);
      
      // Processar lugares para buscar placeId real se possível
      if (parsed.places && Array.isArray(parsed.places)) {
        for (const place of parsed.places) {
          // Aqui poderíamos buscar o placeId real do Google Places
          // Por agora, vamos deixar vazio e o frontend vai buscar quando adicionar
          place.placeId = `temp_${Date.now()}_${Math.random()}`;
        }
      }
      
      return {
        response: parsed.response || 'Aqui estão algumas sugestões para ti!',
        places: parsed.places || []
      };
    } catch (error) {
      console.error('Erro ao gerar sugestões de lugares:', error);
      return {
        response: 'Desculpa, tive dificuldade em processar isso. Podes tentar reformular?',
        places: []
      };
    }
  }

  async generateTripSuggestions(
    preferences: {
      interests: string[];
      budget?: string;
      duration?: number;
      travelStyle?: string;
    }
  ): Promise<TripSuggestion[]> {
    const prompt = `Sugere 5 destinos de viagem baseado nestas preferências:
- Interesses: ${preferences.interests.join(', ')}
- Orçamento: ${preferences.budget || 'médio'}
- Duração: ${preferences.duration || 7} dias
- Estilo de viagem: ${preferences.travelStyle || 'flexível'}

Responde em formato JSON com este schema:
[{
  "destination": "nome do destino",
  "description": "descrição breve do destino",
  "activities": ["atividade1", "atividade2", "atividade3"],
  "bestTimeToVisit": "melhor época para visitar",
  "estimatedBudget": {
    "min": número mínimo em EUR,
    "max": número máximo em EUR,
    "currency": "EUR"
  }
}]

Responde APENAS com o JSON, sem texto adicional.`;

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: 'system', content: this.systemPrompt },
          { role: 'user', content: prompt }
        ],
        temperature: 0.7,
        response_format: { type: 'json_object' }
      });

      const content = response.choices[0]?.message?.content;
      if (!content) return [];

      const parsed = JSON.parse(content);
      return Array.isArray(parsed) ? parsed : (parsed.suggestions || parsed.destinations || []);
    } catch (error) {
      console.error('Erro ao gerar sugestões de viagem:', error);
      throw new Error('Falha ao gerar sugestões de viagem');
    }
  }

  async generateItinerary(
    tripDetails: {
      destination: string;
      startDate: string;
      endDate: string;
      interests: string[];
      pace?: 'relaxed' | 'moderate' | 'intensive';
    }
  ): Promise<ItinerarySuggestion[]> {
    const startDate = new Date(tripDetails.startDate);
    const endDate = new Date(tripDetails.endDate);
    const days = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)) + 1;

    const paceDescriptions = {
      relaxed: '2-3 atividades por dia, com bastante tempo livre',
      moderate: '3-4 atividades por dia, ritmo equilibrado',
      intensive: '5-6 atividades por dia, aproveitando ao máximo'
    };

    const prompt = `Cria um itinerário detalhado para ${days} dias em ${tripDetails.destination}.

Detalhes:
- Data início: ${tripDetails.startDate}
- Data fim: ${tripDetails.endDate}
- Interesses: ${tripDetails.interests.join(', ')}
- Ritmo: ${paceDescriptions[tripDetails.pace || 'moderate']}

Responde em formato JSON com este schema:
{
  "itinerary": [
    {
      "day": 1,
      "activities": [
        {
          "time": "09:00",
          "activity": "nome da atividade",
          "location": "local específico",
          "duration": "2 horas",
          "tips": "dica útil opcional"
        }
      ]
    }
  ]
}

Responde APENAS com o JSON, sem texto adicional.`;

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: 'system', content: this.systemPrompt },
          { role: 'user', content: prompt }
        ],
        temperature: 0.7,
        response_format: { type: 'json_object' }
      });

      const content = response.choices[0]?.message?.content;
      if (!content) return [];

      const parsed = JSON.parse(content);
      return parsed.itinerary || parsed.days || parsed;
    } catch (error) {
      console.error('Erro ao gerar itinerário:', error);
      throw new Error('Falha ao gerar itinerário');
    }
  }

  async chat(
    messages: ChatMessage[],
    context?: {
      tripId?: string;
      destination?: string;
    }
  ): Promise<string> {
    let contextMessage = this.systemPrompt;
    
    if (context?.destination) {
      contextMessage += `\n\nO utilizador está a planear uma viagem para ${context.destination}. Foca as tuas respostas neste destino.`;
    }

    const openaiMessages: OpenAI.Chat.ChatCompletionMessageParam[] = [
      { role: 'system', content: contextMessage },
      ...messages.map(msg => ({
        role: msg.role as 'user' | 'assistant',
        content: msg.content
      }))
    ];

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: openaiMessages,
        temperature: 0.7,
        max_tokens: 1000
      });

      return response.choices[0]?.message?.content || 'Desculpe, não consegui processar o seu pedido.';
    } catch (error) {
      console.error('Erro no chat:', error);
      throw new Error('Falha na comunicação com o assistente');
    }
  }

  async getPlaceRecommendations(
    destination: string,
    interests: string[]
  ): Promise<PlaceRecommendation[]> {
    const prompt = `Recomenda 10 lugares para visitar em ${destination} baseado nestes interesses: ${interests.join(', ')}.

Responde em formato JSON com este schema:
{
  "places": [
    {
      "name": "nome do lugar",
      "description": "descrição breve",
      "category": "categoria (restaurante, museu, parque, etc.)",
      "estimatedDuration": "tempo estimado de visita",
      "priceLevel": "gratuito/económico/moderado/caro"
    }
  ]
}

Responde APENAS com o JSON, sem texto adicional.`;

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: 'system', content: this.systemPrompt },
          { role: 'user', content: prompt }
        ],
        temperature: 0.7,
        response_format: { type: 'json_object' }
      });

      const content = response.choices[0]?.message?.content;
      if (!content) return [];

      const parsed = JSON.parse(content);
      return parsed.places || parsed.recommendations || parsed;
    } catch (error) {
      console.error('Erro ao obter recomendações:', error);
      throw new Error('Falha ao obter recomendações de lugares');
    }
  }

  async translateText(text: string, targetLanguage: string): Promise<string> {
    const languageNames: Record<string, string> = {
      en: 'inglês',
      es: 'espanhol',
      fr: 'francês',
      de: 'alemão',
      it: 'italiano',
      pt: 'português',
      nl: 'holandês',
      ja: 'japonês',
      zh: 'chinês',
      ko: 'coreano'
    };

    const targetLang = languageNames[targetLanguage] || targetLanguage;

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { 
            role: 'system', 
            content: `Você é um tradutor profissional. Traduza o texto para ${targetLang}. Responda APENAS com a tradução, sem explicações.`
          },
          { role: 'user', content: text }
        ],
        temperature: 0.3
      });

      return response.choices[0]?.message?.content || text;
    } catch (error) {
      console.error('Erro ao traduzir:', error);
      throw new Error('Falha ao traduzir texto');
    }
  }

  async analyzeTripSentiment(reviews: string[]): Promise<{
    overall: 'positive' | 'neutral' | 'negative';
    score: number;
    highlights: string[];
    concerns: string[];
  }> {
    const prompt = `Analisa os seguintes reviews/comentários sobre uma viagem ou destino:

${reviews.map((r, i) => `${i + 1}. "${r}"`).join('\n')}

Responde em formato JSON com este schema:
{
  "overall": "positive" ou "neutral" ou "negative",
  "score": número de 0 a 10,
  "highlights": ["ponto positivo 1", "ponto positivo 2"],
  "concerns": ["preocupação 1", "preocupação 2"]
}

Responde APENAS com o JSON, sem texto adicional.`;

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: 'system', content: 'Você é um analista de sentimentos especializado em viagens e turismo.' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.3,
        response_format: { type: 'json_object' }
      });

      const content = response.choices[0]?.message?.content;
      if (!content) {
        return { overall: 'neutral', score: 5, highlights: [], concerns: [] };
      }

      return JSON.parse(content);
    } catch (error) {
      console.error('Erro ao analisar sentimento:', error);
      throw new Error('Falha ao analisar sentimento');
    }
  }

  async getPlaceSuggestions(city: string, country: string, dayNumber?: number): Promise<PlaceRecommendation[]> {
    const dayContext = dayNumber ? `para o dia ${dayNumber} da viagem` : '';
    const location = city && city.trim() ? `${city}, ${country}` : country;
    const prompt = `Sugere 5 lugares/atividades imperdíveis para visitar em ${location} ${dayContext}.

Para cada lugar, inclui:
- Nome do lugar
- Breve descrição (1-2 frases)
- Categoria (ex: museum, restaurant, park, attraction, shopping, nightlife)
- Duração estimada da visita
- Nível de preço (free, budget, moderate, expensive)

Responde em formato JSON com este schema:
{
  "places": [
    {
      "name": "Nome do Lugar",
      "description": "Descrição breve e atrativa",
      "category": "museum",
      "estimatedDuration": "2-3 hours",
      "priceLevel": "moderate"
    }
  ]
}

Foca em lugares variados (cultura, gastronomia, natureza, etc) e populares.
Responde APENAS com o JSON, sem texto adicional.`;

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: 'system', content: 'Você é um guia turístico especializado com conhecimento profundo sobre destinos ao redor do mundo.' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.7,
        response_format: { type: 'json_object' }
      });

      const content = response.choices[0]?.message?.content;
      if (!content) {
        return [];
      }

      const parsed = JSON.parse(content);
      return parsed.places || [];
    } catch (error) {
      console.error('Erro ao obter sugestões de lugares:', error);
      throw new Error('Falha ao obter sugestões de lugares');
    }
  }

  // ============================================
  // Conversation Persistence Methods
  // ============================================

  async createConversation(userId: string, tripId: string | null, title?: string): Promise<any> {
    try {
      console.log('📝 Creating conversation for user:', userId, 'trip:', tripId, 'title:', title);
      
      // Validate trip_id exists if provided
      let validatedTripId = tripId;
      if (tripId) {
        const tripCheck = await query(
          'SELECT id FROM trips WHERE id = $1 AND user_id = $2',
          [tripId, userId]
        );
        
        if (tripCheck.rows.length === 0) {
          console.warn('⚠️ Trip not found or does not belong to user. Creating conversation without trip association.');
          validatedTripId = null;
        }
      }
      
      const result = await query(
        `INSERT INTO ai_conversations (user_id, trip_id, title)
         VALUES ($1, $2, $3)
         RETURNING *`,
        [userId, validatedTripId, title || 'New Conversation']
      );
      console.log('✅ Conversation created:', result.rows[0].id);
      return result.rows[0];
    } catch (error) {
      console.error('❌ Error creating conversation:', error);
      throw new Error('Failed to create conversation');
    }
  }

  async addMessageToConversation(conversationId: string, role: 'user' | 'assistant' | 'system', content: string): Promise<any> {
    try {
      console.log('💬 Adding message to conversation:', conversationId, 'role:', role);
      const result = await query(
        `INSERT INTO ai_messages (conversation_id, role, content)
         VALUES ($1, $2, $3)
         RETURNING *`,
        [conversationId, role, content]
      );
      console.log('✅ Message added:', result.rows[0].id);
      return result.rows[0];
    } catch (error) {
      console.error('❌ Error adding message:', error);
      throw new Error('Failed to add message');
    }
  }

  async getConversations(userId: string, tripId?: string): Promise<any[]> {
    try {
      let queryText = `
        SELECT c.*, 
               COUNT(m.id) as message_count,
               MAX(m.created_at) as last_message_at
        FROM ai_conversations c
        LEFT JOIN ai_messages m ON c.id = m.conversation_id
        WHERE c.user_id = $1`;
      
      const params: any[] = [userId];
      
      if (tripId) {
        queryText += ` AND c.trip_id = $2`;
        params.push(tripId);
      }
      
      queryText += ` GROUP BY c.id ORDER BY c.updated_at DESC`;
      
      const result = await query(queryText, params);
      return result.rows;
    } catch (error) {
      console.error('Error getting conversations:', error);
      return [];
    }
  }

  async getConversationWithMessages(conversationId: string, userId: string): Promise<any | null> {
    try {
      // Get conversation
      const convResult = await query(
        `SELECT * FROM ai_conversations WHERE id = $1 AND user_id = $2`,
        [conversationId, userId]
      );
      
      if (convResult.rows.length === 0) {
        return null;
      }
      
      const conversation = convResult.rows[0];
      
      // Get messages
      const messagesResult = await query(
        `SELECT * FROM ai_messages WHERE conversation_id = $1 ORDER BY created_at ASC`,
        [conversationId]
      );
      
      return {
        ...conversation,
        messages: messagesResult.rows
      };
    } catch (error) {
      console.error('Error getting conversation with messages:', error);
      return null;
    }
  }

  async deleteConversation(conversationId: string, userId: string): Promise<void> {
    try {
      // Verify ownership
      const result = await query(
        `SELECT id FROM ai_conversations WHERE id = $1 AND user_id = $2`,
        [conversationId, userId]
      );
      
      if (result.rows.length === 0) {
        throw new Error('Conversation not found or unauthorized');
      }
      
      // Delete conversation (messages will be deleted by CASCADE)
      await query(
        `DELETE FROM ai_conversations WHERE id = $1`,
        [conversationId]
      );
    } catch (error) {
      console.error('Error deleting conversation:', error);
      throw error;
    }
  }
}

export const aiService = new AIService();
