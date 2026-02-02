# TriplanAI Backend - Guia de Autenticação

## Novas Funcionalidades Implementadas

### 1. **Google OAuth**
- Login e registo com conta Google
- Contas nativas e Google são separadas (mesmo com o mesmo email)
- Token JWT gerado automaticamente após login Google

### 2. **Verificação de Email**
- Email de verificação enviado automaticamente no registo
- Login bloqueado até verificação do email
- Link de verificação válido por 24 horas
- Reenvio de email de verificação disponível

### 3. **Reset de Password**
- Envio de email com link de reset
- Link válido por 1 hora
- Página HTML interativa para definir nova password
- Validação em tempo real de requisitos de password

## Configuração

### 1. Atualizar Base de Dados

Execute o script SQL para adicionar os campos necessários:

```bash
psql -U postgres -d triplanai_db -f database/add_auth_fields.sql
```

### 2. Configurar Variáveis de Ambiente

Copie o `.env.example` para `.env` e preencha:

```bash
cp .env.example .env
```

**Configuração de Email (Gmail):**
1. Ative a verificação em 2 etapas: https://myaccount.google.com/security
2. Crie uma "App Password": https://myaccount.google.com/apppasswords
3. Use essa password no `EMAIL_PASSWORD`

**Configuração Google OAuth:**
1. Aceda a: https://console.cloud.google.com/
2. Crie um novo projeto ou selecione existente
3. Ative a Google+ API
4. Crie credenciais OAuth 2.0
5. Adicione URLs autorizados:
   - `http://localhost:4500` (desenvolvimento)
   - `https://your-app.com` (produção)
6. Copie Client ID e Client Secret para o `.env`

### 3. Instalar Dependências

```bash
npm install
```

## Endpoints da API

### Autenticação Nativa

#### Registo
```http
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "username": "username",
  "password": "password123",
  "full_name": "User Name",
  "phone": "+351912345678" // opcional
}
```

**Resposta:**
```json
{
  "user": { ... },
  "token": "jwt_token",
  "message": "Account created! Please check your email to verify your account."
}
```

#### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "identifier": "user@example.com", // email ou username
  "password": "password123"
}
```

**Resposta:**
```json
{
  "user": { ... },
  "token": "jwt_token"
}
```

**Erros possíveis:**
- `Por favor, verifique o seu email antes de fazer login`
- `Credenciais inválidas`

### Verificação de Email

#### Verificar Email
```http
POST /api/auth/verify-email
Content-Type: application/json

{
  "token": "verification_token_from_email"
}
```

#### Reenviar Email de Verificação
```http
POST /api/auth/resend-verification
Content-Type: application/json

{
  "email": "user@example.com"
}
```

### Reset de Password

#### Solicitar Reset
```http
POST /api/auth/forgot-password
Content-Type: application/json

{
  "email": "user@example.com"
}
```

#### Redefinir Password
```http
POST /api/auth/reset-password
Content-Type: application/json

{
  "token": "reset_token_from_email",
  "password": "new_password123"
}
```

### Google OAuth

#### Login com Google
```http
POST /api/auth/google
Content-Type: application/json

{
  "googleId": "google_user_id",
  "email": "user@gmail.com",
  "name": "User Name",
  "picture": "https://...", // opcional
  "accessToken": "google_access_token",
  "refreshToken": "google_refresh_token" // opcional
}
```

**Resposta:**
```json
{
  "user": { ... },
  "token": "jwt_token",
  "isNewUser": true // ou false
}
```

## Páginas HTML

### Reset de Password
- **URL:** `http://localhost:4500/auth/reset-password.html?token=xxx`
- **Features:**
  - Validação de password em tempo real
  - Design responsivo
  - Feedback visual de erros/sucesso
  - Deep link para voltar à app

### Verificação de Email
- **URL:** `http://localhost:4500/auth/verify-email.html?token=xxx`
- **Features:**
  - Verificação automática ao carregar
  - Loading spinner
  - Redirecionamento automático para a app após 3s
  - Mensagens de erro claras

## Integração no Flutter

### Exemplo de Registo

```dart
Future<void> register(String email, String username, String password, String fullName) async {
  final response = await http.post(
    Uri.parse('$API_URL/auth/register'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'username': username,
      'password': password,
      'full_name': fullName,
    }),
  );

  if (response.statusCode == 201) {
    final data = jsonDecode(response.body);
    // Mostrar mensagem: "Verifique o seu email"
    // data['message'] contém a mensagem
  }
}
```

### Exemplo de Login

```dart
Future<void> login(String identifier, String password) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      // Guardar token e navegar para home
    } else {
      final error = jsonDecode(response.body);
      if (error['error'].contains('verifique o seu email')) {
        // Mostrar diálogo oferecendo reenviar email
      }
    }
  } catch (e) {
    // Handle error
  }
}
```

### Google Sign In (Flutter)

Adicione ao `pubspec.yaml`:
```yaml
dependencies:
  google_sign_in: ^6.1.5
```

```dart
import 'package:google_sign_in/google_sign_in.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
);

Future<void> signInWithGoogle() async {
  try {
    final GoogleSignInAccount? account = await _googleSignIn.signIn();
    if (account == null) return; // User cancelled

    final GoogleSignInAuthentication auth = await account.authentication;
    
    // Send to backend
    final response = await http.post(
      Uri.parse('$API_URL/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'googleId': account.id,
        'email': account.email,
        'name': account.displayName ?? '',
        'picture': account.photoUrl,
        'accessToken': auth.accessToken,
        'idToken': auth.idToken,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      final isNewUser = data['isNewUser'];
      
      // Save token and navigate
      if (isNewUser) {
        // Show welcome message
      }
    }
  } catch (e) {
    // Handle error
  }
}
```

## Deep Links

Configure deep links para abrir a app a partir dos emails:

### Android (`android/app/src/main/AndroidManifest.xml`):
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="triplanai" android:host="app" />
</intent-filter>
```

### iOS (`ios/Runner/Info.plist`):
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>triplanai</string>
        </array>
    </dict>
</array>
```

## Testes

### Testar Email Localmente

Use um serviço como [Mailtrap](https://mailtrap.io/) para testes:

```env
EMAIL_HOST=smtp.mailtrap.io
EMAIL_PORT=2525
EMAIL_USER=your_mailtrap_user
EMAIL_PASSWORD=your_mailtrap_password
```

### Testar Páginas HTML

1. Inicie o backend: `npm run dev`
2. Aceda a: `http://localhost:4500/auth/reset-password.html?token=test`
3. Aceda a: `http://localhost:4500/auth/verify-email.html?token=test`

## Notas Importantes

1. **Segurança de Passwords:**
   - Mínimo 6 caracteres
   - Hashed com bcrypt (10 rounds)

2. **Tokens:**
   - Verificação de email: 24h de validade
   - Reset de password: 1h de validade
   - JWT: 365 dias de validade

3. **Contas Separadas:**
   - Conta nativa: requer password
   - Conta Google: não tem password
   - Mesmo email pode ter ambas as contas

4. **Rate Limiting:**
   - Considere adicionar rate limiting para proteção contra spam

## Troubleshooting

### Emails não são enviados
- Verifique credenciais no `.env`
- Confirme que "App Password" está correto (Gmail)
- Verifique logs do backend para erros

### Token inválido/expirado
- Tokens têm validade limitada
- Use o endpoint de reenvio para gerar novo token

### Google OAuth falha
- Confirme Client ID e Secret
- Verifique URLs autorizados no Google Console
- Certifique-se que Google+ API está ativada

## Próximos Passos

1. Adicionar rate limiting para segurança
2. Implementar refresh tokens
3. Adicionar autenticação de 2 fatores
4. Implementar OAuth com Facebook/Apple
5. Adicionar logging de tentativas de login

