# Use Node.js 20 for the frontend build stage
FROM node:20-alpine AS frontend-build

# Set working directory
WORKDIR /app/web

# Copy package files and install dependencies
COPY web/package*.json ./
RUN npm install

# Copy the rest of the frontend source code and build
COPY web/ ./
RUN npm run build

# Use Go 1.22 for the backend build stage
FROM golang:1.22-alpine AS backend-build

# Set working directory
WORKDIR /app

# Copy Go module files and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy all Go source code and build the binary
COPY . .
RUN go build -o navidrome-sync

# Use a minimal base image for the final stage
FROM alpine:latest

# Set working directory
WORKDIR /app

# Copy the built Go binary
COPY --from=backend-build /app/navidrome-sync ./

# Copy the frontend build output
COPY --from=frontend-build /app/web/dist ./static

# Expose the application port
EXPOSE 8080

# Set the entrypoint
ENTRYPOINT ["/app/navidrome-sync"]