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
  private getLanguageName(language: string = 'en'): string {
    const normalized = language.toLowerCase();
    const base = normalized.split('-')[0];
    return LANGUAGE_NAMES[normalized] || LANGUAGE_NAMES[base] || 'English';
  }

  private normalizeQuery(query: string): string {
    return (query || '')
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '');
  }

  private getWhyIntentHints(): string[] {
    return [
      // English
      'why',
      'reason',
      // Portuguese
      'por que',
      'porque',
      'motivo',
      'razao',
      // Spanish
      'por que',
      'porque',
      'motivo',
      'razon',
      // French
      'pourquoi',
      'raison',
      // German
      'warum',
      'grund',
      // Italian
      'perche',
      'ragione',
      // Dutch
      'waarom',
      'reden',
      // Japanese
      'なぜ',
      'どうして',
      '理由',
      // Korean
      '왜',
      '이유',
      // Chinese (simplified/traditional)
      '为什么',
      '為什麼',
      '为何',
      '為何',
      '原因'
    ];
  }

  private getPlaceListIntentHints(): string[] {
    return [
      // English
      'what to visit',
      'what to see',
      'what to do',
      'things to do',
      'must see',
      'must-visit',
      'top places',
      'top spots',
      'recommend',
      'suggest',
      'suggestions',
      'recommendations',
      'list',
      'places',
      'options',
      'alternatives',
      // Portuguese
      'o que visitar',
      'que visitar',
      'o que ver',
      'que ver',
      'o que fazer',
      'que fazer',
      'recomenda',
      'recomendar',
      'recomendacoes',
      'sugere',
      'sugerir',
      'lista',
      'lugares',
      'mais lugares',
      'mais opcoes',
      // Spanish
      'que visitar',
      'que ver',
      'que hacer',
      'recomienda',
      'recomendar',
      'recomendaciones',
      'sugerencias',
      'lista',
      'lugares',
      'sitios',
      // French
      'que visiter',
      'que voir',
      'que faire',
      'recommande',
      'recommander',
      'recommandations',
      'liste',
      'lieux',
      'endroits',
      // German
      'was besuchen',
      'was sehen',
      'was tun',
      'empfehle',
      'empfehlen',
      'empfehlungen',
      'liste',
      'orte',
      'sehenswurdigkeiten',
      // Italian
      'cosa visitare',
      'cosa vedere',
      'cosa fare',
      'consiglia',
      'consigliare',
      'raccomandazioni',
      'lista',
      'luoghi',
      'posti',
      // Dutch
      'wat bezoeken',
      'wat te zien',
      'wat te doen',
      'aanbevelen',
      'aanbevelingen',
      'lijst',
      'plekken',
      // Japanese
      'おすすめ',
      '何を見る',
      '何する',
      '訪れる',
      '場所',
      'スポット',
      '一覧',
      // Korean
      '추천',
      '뭐 볼',
      '무엇을 볼',
      '뭐 할',
      '무엇을 할',
      '가볼만한',
      '장소',
      '목록',
      // Chinese (simplified/traditional)
      '推荐',
      '推薦',
      '去哪',
      '看什么',
      '看什麼',
      '做什么',
      '做什麼',
      '景点',
      '景點',
      '地方',
      '列表',
      '清单',
      '清單'
    ];
  }

  private containsAnyHint(normalizedQuery: string, hints: string[]): boolean {
    return hints.some((hint) => normalizedQuery.includes(hint));
  }

  private isExplanationOnlyQuery(query: string): boolean {
    const normalized = this.normalizeQuery(query);

    const asksWhy = this.containsAnyHint(normalized, this.getWhyIntentHints());
    const asksForMoreOptions = this.containsAnyHint(
      normalized,
      this.getPlaceListIntentHints(),
    );

    return asksWhy && !asksForMoreOptions;
  }

  private isPlaceListQuery(query: string): boolean {
    const normalized = this.normalizeQuery(query);
    return this.containsAnyHint(normalized, this.getPlaceListIntentHints());
  }

  private async generatePlacesFallback(params: {
    query: string;
    location: string;
    dayNumber: number;
    language?: string;
  }): Promise<any[]> {
    const responseLanguage = this.getLanguageName(params.language || 'en');
    const fallbackPrompt = `The user asked: "${params.query}".
Location context: ${params.location || 'unknown'}.
Day: ${params.dayNumber}.

Return ONLY a places list with 4-5 concrete options relevant to this request.
Do not return an explanation paragraph.

Respond in JSON with this schema:
{
  "places": [
    {
      "name": "place name",
      "category": "category",
      "placeId": "leave empty",
      "description": "short practical description with why it fits"
    }
  ]
}

IMPORTANT: All text MUST be in ${responseLanguage}.
Respond ONLY with JSON.`;

    try {
      const response = await openai.chat.completions.create({
        model: MODEL,
        messages: [
          { role: 'system', content: this.getSystemPrompt(params.language) },
          { role: 'user', content: fallbackPrompt }
        ],
        temperature: 0.5,
        response_format: { type: 'json_object' }
      });

      const content = response.choices[0]?.message?.content;
      if (!content) return [];

      const parsed = JSON.parse(content);
      return Array.isArray(parsed.places) ? parsed.places : [];
    } catch (error) {
      console.error('Error generating fallback places list:', error);
      return [];
    }
  }

  // Gerar system prompt dinâmico baseado na língua
  private getSystemPrompt(language: string = 'en'): string {
    const langName = this.getLanguageName(language);
    
    return `You are a specialized travel assistant called TriplanAI.
You help users plan trips, suggest destinations, create itineraries, and provide practical travel advice.

IMPORTANT LANGUAGE RULE:
- Always respond in ${langName}. The user's language is ${language}.

VOICE & TONE:
- Sound human, warm, and professional.
- Avoid robotic phrasing and generic list-only answers.
- Explain recommendations as if you are a trusted travel advisor.

REASONING & QUALITY:
- Justify suggestions with clear criteria: logistics, variety, time fit, budget fit, and user intent.
- Be critical and honest: point out trade-offs, weak options, and better alternatives when relevant.
- If the user asks "why these places", answer directly with concrete reasoning.
- If the user asks why a specific place is recommended, focus on that place only and do not add extra place lists unless explicitly asked.
- Prefer realistic plans over overpacked itineraries.

PRACTICALITY:
- Include actionable details (best timing, expected pace, rough costs, local tips, reservation advice).
- Never invent certainty for unknown data; when unsure, state assumptions briefly.
- Keep answers concise but complete, with a clear recommendation and next best step.`;
  }

  async generatePlaceSuggestions(params: {
    query: string;
    location: string;
    dayNumber: number;
    language?: string;
  }): Promise<{ response: string; places: any[] }> {
    const systemPrompt = this.getSystemPrompt(params.language);
    const responseLanguage = this.getLanguageName(params.language || 'en');
    const explanationOnly = this.isExplanationOnlyQuery(params.query);
    const mustReturnPlaces = this.isPlaceListQuery(params.query) && !explanationOnly;
    const prompt = `The user is planning day ${params.dayNumber} in ${params.location}.
Question: "${params.query}"

Choose response format based on intent:
- EXPLANATION mode: if the user is asking "why" (or equivalent) about a specific recommendation/place, answer that question directly and do NOT add extra place suggestions.
- SUGGESTION mode: if the user asks for ideas/options, provide place suggestions.
- Default to SUGGESTION mode unless the user explicitly asks "why".

Quality requirements:
- In EXPLANATION mode:
  - Keep the response focused on the asked place/recommendation.
  - Use 1-2 short paragraphs with concrete reasons and one practical tip.
  - Return "places": []
- In SUGGESTION mode:
  - Suggest 4-5 relevant places with good diversity (culture, food, views, local life, etc. when possible).
  - Build a coherent day flow (avoid unrealistic jumps across the city).
  - Be critical: mention one key trade-off or caveat (crowds, timing, budget, distance, reservation risk).
  - The response text must explain why these places are good for this user question.
  - Each place description should include both "why it fits" and one practical tip.

Respond in JSON format with this schema:
{
  "response": "natural, advisor-style response in ${responseLanguage}, including reasoning and one critical caveat",
  "places": [{
    "name": "place name",
    "category": "category (e.g.: Accommodation, Restaurant, Museum, Park, Shopping, Activities & Experiences, Nature & Outdoor)",
    "placeId": "leave empty for now, will be filled later",
    "description": "brief but useful description including why it fits and one practical tip"
  }]
}

IMPORTANT:
- The "response" field MUST be in ${responseLanguage}.
- If this is EXPLANATION mode, the "places" array must be empty.
- If this is SUGGESTION mode, include 4-5 places in the "places" array.
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
        if (mustReturnPlaces) {
          const fallbackPlaces = await this.generatePlacesFallback(params);
          return {
            response: this.getDefaultSuggestionsMessage(params.language),
            places: fallbackPlaces,
          };
        }

        return {
          response: this.getDefaultErrorMessage(params.language),
          places: []
        };
      }

      const parsed = JSON.parse(content);
      let places = Array.isArray(parsed.places) ? parsed.places : [];

      // Enforce direct-answer behavior for "why recommend X" queries.
      if (explanationOnly) {
        places = [];
      }

      // Enforce list behavior for "what to visit"/list queries.
      if (mustReturnPlaces && places.length === 0) {
        places = await this.generatePlacesFallback(params);
      }
      
      // Processar lugares para buscar placeId real se possível
      if (Array.isArray(places)) {
        for (const place of places) {
          // Aqui poderíamos buscar o placeId real do Google Places
          // Por agora, vamos deixar vazio e o frontend vai buscar quando adicionar
          place.placeId = `temp_${Date.now()}_${Math.random()}`;
        }
      }
      
      return {
        response: parsed.response || this.getDefaultSuggestionsMessage(params.language),
        places: Array.isArray(places) ? places : []
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
    const responseLanguage = this.getLanguageName(lang);
    
    const prompt = `Suggest 5 travel destinations based on these preferences:
- Interests: ${preferences.interests.join(', ')}
- Budget: ${preferences.budget || 'medium'}
- Duration: ${preferences.duration || 7} days
- Travel style: ${preferences.travelStyle || 'flexible'}

Be opinionated and practical: prioritize fit over generic popularity.
For each destination, focus on what makes it genuinely suitable for this profile.
Avoid repetitive suggestions and include variety.

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

IMPORTANT: All text content MUST be in ${responseLanguage}.
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
    const responseLanguage = this.getLanguageName(lang);
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

Build a realistic itinerary with strong sequencing and practical timing.
If a plan would be inefficient, adjust it and reflect the rationale in tips.
Be selective and quality-focused rather than overpacking the day.

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

IMPORTANT: All text content MUST be in ${responseLanguage}.
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
    const responseLanguage = this.getLanguageName(lang);
    
    const prompt = `Recommend 10 places to visit in ${destination} based on these interests: ${interests.join(', ')}.

Do not give a bland list.
Choose places with strong fit and include practical/advisor-style reasoning.
If some options are popular but weakly aligned, deprioritize them.

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

IMPORTANT: All text content MUST be in ${responseLanguage}.
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

Foca em lugares variados (cultura, gastronomia, natureza, etc) e populares,
mas com pensamento crítico: evita escolhas redundantes e equilibra logística.
Em cada descrição, inclui "porque vale a pena" e uma dica prática.
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
