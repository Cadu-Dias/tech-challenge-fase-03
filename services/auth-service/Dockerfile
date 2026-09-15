# ---- Build stage ----
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Cache de dependências
COPY go.mod ./
RUN go mod download 2>/dev/null || true

COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /auth-service .

# ---- Runtime stage ----
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /
COPY --from=builder /auth-service /auth-service
COPY --from=builder /app/db /db

EXPOSE 8001
USER nonroot:nonroot
ENTRYPOINT ["/auth-service"]
