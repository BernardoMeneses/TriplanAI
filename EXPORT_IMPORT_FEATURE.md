# Funcionalidade de Exportar/Importar Viagens

## 📋 Descrição

Sistema profissional de exportação/importação de viagens com **encriptação AES-256** e extensão personalizada `.triplan`. Quando um utilizador recebe um ficheiro `.triplan` e clica nele, o sistema operativo oferece **"Abrir com TriplanAI"**, garantindo que apenas a app pode importar as viagens.

## 🔐 Características Principais

- ✅ **Encriptação AES-256** - Dados completamente protegidos
- ✅ **Extensão `.triplan`** - Ficheiro personalizado, não editável
- ✅ **Deep Linking** - Abrir ficheiros diretamente na app
- ✅ **Auto-importação** - Reconhecimento automático ao clicar
- ✅ **Obriga uso da app** - Impossível editar manualmente

## 🚀 Funcionalidades Implementadas

### Backend (Node.js/TypeScript)

#### 1. Endpoint de Exportação
- **Rota:** `GET /api/trips/:id/export`
- **Descrição:** Exporta todos os dados de uma viagem incluindo:
  - Informações da viagem (título, destino, datas, orçamento, etc.)
  - Todos os itinerários do dia a dia
  - Todos os items de cada itinerário com detalhes de lugares
- **Resposta:** Arquivo JSON com estrutura versionada

#### 2. Endpoint de Importação
- **Rota:** `POST /api/trips/import`
- **Descrição:** Importa uma viagem de um JSON exportado
- **Funcionalidades:**
  - Valida estrutura do JSON
  - Cria nova viagem para o utilizador autenticado
  - Importa todos os itinerários e items
  - Cria ou reutiliza lugares existentes
- **Resposta:** Objeto da nova viagem criada

### Frontend (Flutter/Dart)

#### 1. Serviço de Encriptação (`encryption_service.dart`)
- **Encriptação AES-256** com chave fixa da app
- **Validação**: Marca d'água TriplanAI nos dados
- **Formato**: `TRIPLAN_V1:{base64_encrypted_data}`
- **Segurança**: Hash SHA-256 para integridade

#### 2. Serviço de Partilha (`trip_share_service.dart`)
- **Métodos:**
  - `exportTripToFile()`: Exporta para ficheiro `.triplan` encriptado
  - `shareTrip()`: Partilha ficheiro via sistema nativo
  - `importTripFromFile()`: Importa e desencripta ficheiro `.triplan`
  - `importTripFromEncryptedString()`: Importa de string encriptada

#### 3. Serviço de Deep Linking (`deep_link_service.dart`)
- **Auto-detecção** de ficheiros `.triplan` recebidos
- **Importação automática** quando utilizador clica no ficheiro
- **Feedback visual** durante importação
- **Tratamento de erros** robusto

#### 4. UI na Página de Detalhes da Viagem
- **Localização:** Menu de opções (ícone ⋮) na página `my_trip_page.dart`
- **Opções:**
  - 🔗 **Partilhar viagem**: Abre menu de partilha nativo
  - 📥 **Exportar JSON**: Guarda arquivo JSON localmente
  - ✏️ **Editar viagem**: Opção de edição existente

#### 5. Página de Importação (`import_trip_page.dart`)
- **Acesso:** Botão de download na página de viagens
- **Funcionalidades:**
  - Seleção de arquivo `.triplan` encriptado
  - Desencriptação e validação automática
  - Pré-visualização dos dados da viagem
  - Importação com feedback visual

## 📱 Como Usar

### Para Exportar/Partilhar:

1. Abrir detalhes de uma viagem
2. Clicar no menu de opções (⋮) no canto superior direito
3. Escolher:
   - **"Partilhar viagem"** para enviar por WhatsApp, Instagram, etc.
   - **"Exportar JSON"** para guardar o arquivo localmente
4. Ficheiro `.triplan` **encriptado** é partilhado

### Para Importar (AUTOMÁTICO - Recomendado):

1. Receber ficheiro `.triplan` (WhatsApp, Email, etc.)
2. **Clicar no ficheiro**
3. Sistema mostra: **"Abrir com TriplanAI"**
4. Selecionar TriplanAI
5. App **abre automaticamente** e importa a viagem
6. Viagem aparece na lista instantaneamente ✨

### Para Importar (Manual):

1. Na página "Your trips", clicar no ícone de download no topo
2. Selecionar o arquivo `.triplan` recebido
3. Revisar a pré-visualização da viagem
4. Clicar em "Importar Viagem"
5. A viagem aparecerá automaticamente na lista

## 🔧 Estrutura do Ficheiro .triplan

O ficheiro `.triplan` contém dados **encriptados** no formato:

```
TRIPLAN_V1:{base64_encrypted_data}
```

Quando desencriptado, contém:

```json
{
  "_app": "TriplanAI",
  "_encrypted_at": "2026-01-23T10:30:00.000Z",
  "version": "1.0",
  "exportedAt": "2026-01-23T10:30:00.000Z",
  "trip": {
    "title": "Viagem a Paris",
    "description": "Uma aventura incrível",
    "destination_city": "Paris",
    "destination_country": "França",
    "start_date": "2026-06-01",
    "end_date": "2026-06-07",
    "budget": 2000,
    "currency": "EUR",
    "trip_type": "leisure",
    "number_of_travelers": 2
  },
  "itineraries": [
    {
      "day_number": 1,
      "date": "2026-06-01",
      "title": "Chegada e Torre Eiffel",
      "items": [
        {
          "title": "Visita à Torre Eiffel",
          "start_time": "14:00",
          "duration_minutes": 120,
          "item_type": "attraction",
          "place": {
            "name": "Torre Eiffel",
            "google_place_id": "ChIJLU7jZClu5kcR4PcOOO6p3I0",
            "latitude": 48.8584,
            "longitude": 2.2945
          }
        }
      ]
    }
  ]
}
```

## 📦 Dependências Necessárias

### Flutter (pubspec.yaml)
```yaml
dependencies:
  share_plus: ^7.0.0           # Partilha de ficheiros
  path_provider: ^2.1.0         # Acesso a diretórios
  file_picker: ^6.0.0           # Seleção de ficheiros
  encrypt: ^5.0.3               # Encriptação AES
  crypto: ^3.0.3                # Funções criptográficas
  receive_sharing_intent: ^1.8.0 # Deep linking para ficheiros
```

### Instalação:
```bash
flutter pub add share_plus path_provider file_picker encrypt crypto receive_sharing_intent
```

## ⚙️ Configurações Adicionais

### Android (AndroidManifest.xml)

Adicionar dentro da tag `<activity>` principal:

```xml
<!-- Intent filter para abrir arquivos .triplan -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    
    <data android:scheme="file" />
    <data android:scheme="content" />
    <data android:mimeType="*/*" />
    <data android:pathPattern=".*\\.triplan" />
    <data android:host="*" />
</intent-filter>

<!-- Suporte para compartilhamento -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="*/*" />
</intent-filter>
```

### iOS (Info.plist)

Adicionar antes do `</dict>` final:

```xml
<!-- Tipos de documento suportados -->
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>TriplanAI Trip File</string>
        <key>LSHandlerRank</key>
        <string>Owner</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.triplanai.trip</string>
        </array>
    </dict>
</array>

<!-- Declaração do tipo .triplan -->
<key>UTExportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.data</string>
        </array>
        <key>UTTypeDescription</key>
        <string>TriplanAI Trip File</string>
        <key>UTTypeIdentifier</key>
        <string>com.triplanai.trip</string>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>triplan</string>
            </array>
        </dict>
    </dict>
</array>

<!-- Esquemas para redes sociais -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>whatsapp</string>
    <string>instagram</string>
    <string>fb</string>
</array>
```

### main.dart - Inicializar Deep Linking

```dart
import 'services/deep_link_service.dart';

class _MyAppState extends State<MyApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinkService.initialize(
        context,
        (trip) {
          // Navegar para viagem importada
          Navigator.pushNamed(context, '/trip-details', arguments: trip);
        },
      );
    });
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }
  // ...
}
```

## 🔐 Segurança

- ✅ Apenas utilizadores autenticados podem importar viagens
- ✅ Cada viagem importada é criada com o ID do utilizador atual
- ✅ Validação de estrutura do JSON antes da importação
- ✅ Gestão adequada de lugares duplicados (reutiliza se já existir)

## 🐛 Tratamento de Erros

A implementação inclui tratamento robusto de erros:
- Formato JSON inválido
- Falhas na conexão ao backend
- Problemas ao guardar/ler arquivos
- Feedback visual para o utilizador em todos os casos

## 📝 Notas Técnicas

1. **Versionamento**: O JSON inclui campo `version` para compatibilidade futura
2. **IDs**: IDs originais não são preservados, novos IDs são gerados
3. **Utilizador**: A viagem importada fica associada ao utilizador que importa
4. **Lugares**: Sistema inteligente evita duplicação de lugares usando `google_place_id`
5. **Datas**: Formato ISO 8601 para compatibilidade internacional

## 🎯 Próximos Passos Sugeridos

- [ ] Adicionar compressão do JSON para reduzir tamanho do arquivo
- [ ] Implementar importação via URL/QR Code
- [ ] Adicionar suporte para importar apenas itinerários específicos
- [ ] Criar versioning mais robusto para futuras alterações
- [ ] Implementar histórico de viagens partilhadas/importadas
