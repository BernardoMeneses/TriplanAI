# TriplanAI Backend

API para planejamento inteligente de viagens com IA.

## 🚀 Começar

### Pré-requisitos

- Node.js 18+
- npm ou yarn

### Instalação

```bash
# Instalar dependências
npm install

# Copiar ficheiro de ambiente
cp .env.example .env

# Configurar variáveis de ambiente no .env
```

### Desenvolvimento

```bash
# Iniciar servidor de desenvolvimento
npm run dev
```

### Produção

```bash
# Compilar TypeScript
npm run build

# Iniciar servidor
npm start
```

## 📚 Documentação API

Após iniciar o servidor, aceda à documentação Swagger em:
- http://localhost:3000/api-docs

## 🏗️ Estrutura do Projeto

```
src/
├── config/
│   ├── firebase.ts      # Configuração Firebase
│   └── swagger.ts       # Configuração Swagger
├── modules/
│   ├── ai/              # Funcionalidades de IA
│   ├── auth/            # Autenticação
│   ├── iteneraries/     # Gestão de itinerários
│   ├── maps/            # Mapas e geolocalização
│   ├── places/          # Locais e pontos de interesse
│   ├── routes/          # Rotas e navegação
│   └── trips/           # Gestão de viagens
└── main.ts              # Ponto de entrada
```

## 🛠️ Módulos

| Módulo | Descrição |
|--------|-----------|
| **Auth** | Registo, login e autenticação de utilizadores |
| **Trips** | CRUD de viagens |
| **Itineraries** | Gestão de itinerários e atividades |
| **Places** | Pesquisa e detalhes de locais |
| **Routes** | Cálculo e otimização de rotas |
| **Maps** | Geocodificação e mapas |
| **AI** | Sugestões e geração de itinerários com IA |

## 📝 API Endpoints

### Auth
- `POST /api/auth/register` - Registar utilizador
- `POST /api/auth/login` - Autenticar
- `POST /api/auth/logout` - Terminar sessão

### Trips
- `GET /api/trips` - Listar viagens
- `POST /api/trips` - Criar viagem
- `GET /api/trips/:id` - Obter viagem
- `PUT /api/trips/:id` - Atualizar viagem
- `DELETE /api/trips/:id` - Eliminar viagem

### Itineraries
- `GET /api/itineraries/trip/:tripId` - Listar itinerários
- `POST /api/itineraries` - Criar itinerário
- `GET /api/itineraries/:id` - Obter itinerário
- `PUT /api/itineraries/:id` - Atualizar itinerário
- `DELETE /api/itineraries/:id` - Eliminar itinerário

### Places
- `GET /api/places/search` - Pesquisar locais
- `GET /api/places/nearby` - Locais próximos
- `GET /api/places/popular/:destination` - Locais populares
- `GET /api/places/:id` - Detalhes do local

### Routes
- `POST /api/routes/calculate` - Calcular rota
- `POST /api/routes/optimize` - Otimizar rota
- `POST /api/routes/alternatives` - Rotas alternativas
- `POST /api/routes/distance-matrix` - Matriz de distâncias

### Maps
- `GET /api/maps/geocode` - Geocodificar endereço
- `GET /api/maps/reverse-geocode` - Geocodificação reversa
- `POST /api/maps/static` - Mapa estático
- `GET /api/maps/timezone` - Fuso horário

### AI
- `POST /api/ai/suggestions` - Sugestões de viagem
- `POST /api/ai/itinerary` - Gerar itinerário
- `POST /api/ai/chat` - Chat com assistente
- `POST /api/ai/recommendations` - Recomendações
- `POST /api/ai/translate` - Traduzir texto

## 🔧 Variáveis de Ambiente

| Variável | Descrição |
|----------|-----------|
| `PORT` | Porta do servidor (default: 3000) |
| `NODE_ENV` | Ambiente (development/production) |
| `FIREBASE_PROJECT_ID` | ID do projeto Firebase |
| `FIREBASE_PRIVATE_KEY` | Chave privada Firebase |
| `FIREBASE_CLIENT_EMAIL` | Email do cliente Firebase |
| `OPENAI_API_KEY` | Chave API OpenAI |
| `GOOGLE_MAPS_API_KEY` | Chave API Google Maps |
| `CORS_ALLOWED_ORIGINS` | Lista de origens permitidas no CORS (separadas por vírgula) |
| `ALLOWED_ORIGINS` | Alias legado para lista de origens permitidas no CORS |
| `FRONTEND_URL` | Origem única do frontend (fallback para CORS) |
| `ADAPTY_WEBHOOK_AUTHORIZATION` | Valor exato esperado no header Authorization do webhook Adapty |
| `ADAPTY_WEBHOOK_AUTHORIZATION_PRODUCTION` | Header Authorization esperado para eventos Adapty de produção |
| `ADAPTY_WEBHOOK_AUTHORIZATION_SANDBOX` | Header Authorization esperado para eventos Adapty de sandbox |
| `ADAPTY_WEBHOOK_AUTH_TOKENS` | Múltiplos tokens Adapty (separados por vírgula) |

Observação: em produção, o backend falha ao iniciar se não houver allowlist de CORS configurada. O webhook do Adapty também exige Authorization configurado para aceitar eventos.

## 📄 Licença

ISC
