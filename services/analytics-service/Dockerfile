# ---- Build stage ----
FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Runtime stage ----
FROM python:3.11-slim

WORKDIR /app

COPY --from=builder /install /usr/local
COPY . .

EXPOSE 8005
# 1 worker para evitar consumidores SQS duplicados (o worker inicia no import do app)
CMD ["gunicorn", "--bind", "0.0.0.0:8005", "--workers", "1", "app:app"]
