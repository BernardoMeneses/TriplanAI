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

// Mapeamento de códigos de língua para nomes
const LANGUAGE_NAMES: Record<string, string> = {
  en: 'English',
  es: 'Spanish (Español)',
  fr: 'French (Français)',
  de: 'German (Deutsch)',
  it: 'Italian (Italiano)',
  pt: 'Portuguese (Português de Portugal)',
  nl: 'Dutch (Nederlands)',
  ja: 'Japanese (日本語)',
  zh: 'Chinese (中文)',
  ko: 'Korean (한국어)',
};

export class AIService {
  // Gerar system prompt dinâmico baseado na língua
  private getSystemPrompt(language: string = 'en'): string {
    const langName = LANGUAGE_NAMES[language] || 'English';
    
    return `You are a specialized travel assistant called TriplanAI.
You help users plan trips, suggest destinations, create itineraries, and provide travel tips.
IMPORTANT: Always respond in ${langName}. The user's language is ${language}.
Be friendly, informative, and practical in your responses.
When suggesting places, include useful information such as opening hours, estimated prices, and practical tips.`;
  }

  async generatePlaceSuggestions(params: {
    query: string;
    location: string;
    dayNumber: number;
    language?: string;
  }): Promise<{ response: string; places: any[] }> {
    const systemPrompt = this.getSystemPrompt(params.language);
    const prompt = `The user is planning day ${params.dayNumber} in ${params.location}.
Question: "${params.query}"

Respond with a friendly message and suggest 4-5 relevant places.

Respond in JSON format with this schema:
{
  "response": "friendly message responding to the user in ${LANGUAGE_NAMES[params.language || 'en'] || 'English'}",
  "places": [{
    "name": "place name",
    "category": "category (e.g.: Accommodation, Restaurant, Museum, Park, Shopping, Activities & Experiences, Nature & Outdoor)",
    "placeId": "leave empty for now, will be filled later",
    "description": "brief description of the place"
  }]
}

IMPORTANT: The "response" field MUST be in ${LANGUAGE_NAMES[params.language || 'en'] || 'English'}.
Respond ONLY with the JSON, no additional text.`;

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: prompt }
        ],
        temperature: 0.7,
        response_format: { type: 'json_object' }
      });

      const content = response.choices[0]?.message?.content;
      if (!content) {
        return {
          response: this.getDefaultErrorMessage(params.language),
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
        response: parsed.response || this.getDefaultSuggestionsMessage(params.language),
        places: parsed.places || []
      };
    } catch (error) {
      console.error('Error generating place suggestions:', error);
      return {
        response: this.getDefaultErrorMessage(params.language),
        places: []
      };
    }
  }

  private getDefaultErrorMessage(language?: string): string {
    const messages: Record<string, string> = {
      pt: 'Desculpa, tive dificuldade em processar isso. Podes tentar reformular?',
      en: 'Sorry, I had trouble processing that. Can you try rephrasing?',
      es: 'Lo siento, tuve dificultades para procesar eso. ¿Puedes intentar reformularlo?',
      fr: 'Désolé, j\'ai eu du mal à traiter cela. Pouvez-vous essayer de reformuler?',
      de: 'Entschuldigung, ich hatte Schwierigkeiten, das zu verarbeiten. Kannst du es anders formulieren?',
      it: 'Mi dispiace, ho avuto difficoltà a elaborare questo. Puoi provare a riformulare?',
    };
    return messages[language || 'en'] || messages.en;
  }

  private getDefaultSuggestionsMessage(language?: string): string {
    const messages: Record<string, string> = {
      pt: 'Aqui estão algumas sugestões para ti!',
      en: 'Here are some suggestions for you!',
      es: '¡Aquí tienes algunas sugerencias!',
      fr: 'Voici quelques suggestions pour vous!',
      de: 'Hier sind einige Vorschläge für dich!',
      it: 'Ecco alcuni suggerimenti per te!',
    };
    return messages[language || 'en'] || messages.en;
  }

  async generateTripSuggestions(
    preferences: {
      interests: string[];
      budget?: string;
      duration?: number;
      travelStyle?: string;
      language?: string;
    }
  ): Promise<TripSuggestion[]> {
    const lang = preferences.language || 'en';
    const systemPrompt = this.getSystemPrompt(lang);
    
    const prompt = `Suggest 5 travel destinations based on these preferences:
- Interests: ${preferences.interests.join(', ')}
- Budget: ${preferences.budget || 'medium'}
- Duration: ${preferences.duration || 7} days
- Travel style: ${preferences.travelStyle || 'flexible'}

Respond in JSON format with this schema:
[{
  "destination": "destination name",
  "description": "brief description",
  "activities": ["activity1", "activity2", "activity3"],
  "bestTimeToVisit": "best time to visit",
  "estimatedBudget": {
    "min": minimum number in EUR,
    "max": maximum number in EUR,
    "currency": "EUR"
  }
}]

IMPORTANT: All text content MUST be in ${LANGUAGE_NAMES[lang] || 'English'}.
Respond ONLY with the JSON, no additional text.`;

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
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
      console.error('Error generating trip suggestions:', error);
      throw new Error('Failed to generate trip suggestions');
    }
  }

  async generateItinerary(
    tripDetails: {
      destination: string;
      startDate: string;
      endDate: string;
      interests: string[];
      pace?: 'relaxed' | 'moderate' | 'intensive';
      language?: string;
    }
  ): Promise<ItinerarySuggestion[]> {
    const lang = tripDetails.language || 'en';
    const systemPrompt = this.getSystemPrompt(lang);
    const startDate = new Date(tripDetails.startDate);
    const endDate = new Date(tripDetails.endDate);
    const days = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)) + 1;

    const paceDescriptions: Record<string, string> = {
      relaxed: '2-3 activities per day, with plenty of free time',
      moderate: '3-4 activities per day, balanced pace',
      intensive: '5-6 activities per day, making the most of it'
    };

    const prompt = `Create a detailed itinerary for ${days} days in ${tripDetails.destination}.

Details:
- Start date: ${tripDetails.startDate}
- End date: ${tripDetails.endDate}
- Interests: ${tripDetails.interests.join(', ')}
- Pace: ${paceDescriptions[tripDetails.pace || 'moderate']}

Respond in JSON format with this schema:
{
  "itinerary": [
    {
      "day": 1,
      "activities": [
        {
          "time": "09:00",
          "activity": "activity name",
          "location": "specific location",
          "duration": "2 hours",
          "tips": "optional useful tip"
        }
      ]
    }
  ]
}

IMPORTANT: All text content MUST be in ${LANGUAGE_NAMES[lang] || 'English'}.
Respond ONLY with the JSON, no additional text.`;

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
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
      console.error('Error generating itinerary:', error);
      throw new Error('Failed to generate itinerary');
    }
  }

  async chat(
    messages: ChatMessage[],
    context?: {
      tripId?: string;
      destination?: string;
      language?: string;
    }
  ): Promise<string> {
    const lang = context?.language || 'en';
    let contextMessage = this.getSystemPrompt(lang);
    
    if (context?.destination) {
      contextMessage += `\n\nThe user is planning a trip to ${context.destination}. Focus your responses on this destination.`;
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

      return response.choices[0]?.message?.content || this.getDefaultErrorMessage(lang);
    } catch (error) {
      console.error('Error in chat:', error);
      throw new Error('Failed to communicate with assistant');
    }
  }

  async getPlaceRecommendations(
    destination: string,
    interests: string[],
    language?: string
  ): Promise<PlaceRecommendation[]> {
    const lang = language || 'en';
    const systemPrompt = this.getSystemPrompt(lang);
    
    const prompt = `Recommend 10 places to visit in ${destination} based on these interests: ${interests.join(', ')}.

Respond in JSON format with this schema:
{
  "places": [
    {
      "name": "place name",
      "description": "brief description",
      "category": "category (restaurant, museum, park, etc.)",
      "estimatedDuration": "estimated visit time",
      "priceLevel": "free/budget/moderate/expensive"
    }
  ]
}

IMPORTANT: All text content MUST be in ${LANGUAGE_NAMES[lang] || 'English'}.
Respond ONLY with the JSON, no additional text.`;

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
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

  async addMessageToConversation(conversationId: string, role: 'user' | 'assistant' | 'system', content: string, metadata?: any): Promise<any> {
    try {
      console.log('💬 Adding message to conversation:', conversationId, 'role:', role);
      const result = await query(
        `INSERT INTO ai_messages (conversation_id, role, content, metadata)
         VALUES ($1, $2, $3, $4)
         RETURNING *`,
        [conversationId, role, content, metadata || {}]
      );
      console.log('✅ Message added:', result.rows[0].id);
      return result.rows[0];
    } catch (error) {
      console.error('❌ Error adding message:', error);
      throw new Error('Failed to add message');
    }
  }

  async getConversations(userId: string, tripId?: string, dayNumber?: number): Promise<any[]> {
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
      
      if (dayNumber !== undefined) {
        queryText += ` AND c.title LIKE $${params.length + 1}`;
        params.push(`Day ${dayNumber}%`);
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
