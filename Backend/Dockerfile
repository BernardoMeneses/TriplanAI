# Multi-stage build para otimizar tamanho da imagem
FROM node:20-alpine AS builder

# Instalar dependências necessárias
RUN apk add --no-cache python3 make g++

# Diretório de trabalho
WORKDIR /app

# Copiar arquivos de dependências
COPY package*.json ./
COPY tsconfig.json ./

# Instalar dependências
RUN npm ci --only=production && npm cache clean --force

# Copiar código fonte
COPY src ./src

#Instalar TypeScript globalmente
RUN npm install -g typescript
# Build da aplicação
RUN npm run build

# Estágio de produção
FROM node:20-alpine

# Instalar dependências runtime
RUN apk add --no-cache tini

WORKDIR /app

# Copiar node_modules e build do estágio anterior
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

# Criar usuário não-root para segurança
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

# Expor porta da aplicação
EXPOSE 3000

# Usar tini como init para lidar corretamente com sinais
ENTRYPOINT ["/sbin/tini", "--"]

# Comando para iniciar a aplicação
CMD ["node", "dist/main.js"]
