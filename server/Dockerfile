FROM node:18-alpine

WORKDIR /app

# Install dependencies for Prisma
RUN apk add --no-cache openssl

COPY package*.json ./
RUN npm install

COPY . .

# Generate Prisma client
RUN npx prisma generate

# Expose the DATABASE_URL ARG as a runtime ENV so Node.js can read it
ARG DATABASE_URL
ENV DATABASE_URL=${DATABASE_URL}

EXPOSE 3000

CMD ["npm", "start"]
