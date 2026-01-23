# Funcionalidade de Exportar/Importar Viagens

## 📋 Descrição

Esta funcionalidade permite que utilizadores exportem viagens completas em formato JSON e as partilhem com outros utilizadores através de redes sociais (WhatsApp, Instagram, etc.). Os destinatários podem então importar essas viagens para as suas próprias contas.

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

#### 1. Serviço de Partilha (`trip_share_service.dart`)
- **Métodos:**
  - `exportTripToFile()`: Exporta viagem para arquivo JSON temporário
  - `shareTrip()`: Partilha arquivo JSON via sistema de partilha nativo
  - `importTripFromFile()`: Importa viagem de um arquivo JSON
  - `importTripFromJson()`: Importa viagem de dados JSON diretos

#### 2. UI na Página de Detalhes da Viagem
- **Localização:** Menu de opções (ícone ⋮) na página `my_trip_page.dart`
- **Opções:**
  - 🔗 **Partilhar viagem**: Abre menu de partilha nativo
  - 📥 **Exportar JSON**: Guarda arquivo JSON localmente
  - ✏️ **Editar viagem**: Opção de edição existente

#### 3. Página de Importação (`import_trip_page.dart`)
- **Acesso:** Botão de download na página de viagens
- **Funcionalidades:**
  - Seleção de arquivo JSON
  - Pré-visualização dos dados da viagem
  - Validação de formato
  - Importação com feedback visual

## 📱 Como Usar

### Para Exportar/Partilhar:

1. Abrir detalhes de uma viagem
2. Clicar no menu de opções (⋮) no canto superior direito
3. Escolher:
   - **"Partilhar viagem"** para enviar por WhatsApp, Instagram, etc.
   - **"Exportar JSON"** para guardar o arquivo localmente

### Para Importar:

1. Na página "Your trips", clicar no ícone de download no topo
2. Selecionar o arquivo JSON recebido
3. Revisar a pré-visualização da viagem
4. Clicar em "Importar Viagem"
5. A viagem aparecerá automaticamente na lista

## 🔧 Estrutura do JSON

```json
{
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
  share_plus: ^7.0.0  # Para partilha de arquivos
  path_provider: ^2.1.0  # Para acesso a diretórios
  file_picker: ^6.0.0  # Para seleção de arquivos
```

### Instalação:
```bash
flutter pub add share_plus path_provider file_picker
```

## ⚙️ Configurações Adicionais

### Android (AndroidManifest.xml)
Não são necessárias permissões especiais para esta funcionalidade.

### iOS (Info.plist)
Adicionar se necessário partilhar para redes sociais específicas:
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>whatsapp</string>
    <string>instagram</string>
</array>
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
