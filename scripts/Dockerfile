# Dockerfile — WSP001 Vector Retrieval Service
# FOR THE COMMONS GOOD — reusable across WSP001 repos
#
# Build:  docker build -t rse-retrieval -f scripts/Dockerfile .
# Run:    docker run -p 8080:8080 -e GEMINI_API_KEY=xxx rse-retrieval
# Push:   docker tag rse-retrieval gcr.io/YOUR_PROJECT_ID/rse-retrieval
#         docker push gcr.io/YOUR_PROJECT_ID/rse-retrieval

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (layer caching)
# Build context is the scripts/ directory when deployed via --source ./scripts
COPY requirements.txt ./requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY api_server.py ./api_server.py
COPY embed_engine.py ./embed_engine.py

# Create ChromaDB data directory
RUN mkdir -p /data/chromadb
ENV CHROMADB_PATH=/data/chromadb

# Cloud Run sets PORT automatically — default 8080
ENV PORT=8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Non-root user (security best practice)
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app /data
USER appuser

# Start FastAPI server
CMD ["sh", "-c", "uvicorn api_server:app --host 0.0.0.0 --port ${PORT}"]
