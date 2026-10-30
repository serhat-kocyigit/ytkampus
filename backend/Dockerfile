FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN apk add --no-cache ffmpeg ttf-dejavu
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
