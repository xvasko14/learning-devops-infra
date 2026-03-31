# Build stage — nainštaluje dependencies do separátneho priečinka
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/app/packages -r requirements.txt

# Runtime stage — len to čo treba na spustenie (menší image)
FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /app/packages /app/packages
COPY main.py .
ENV PYTHONPATH=/app/packages
EXPOSE 8080
CMD ["python", "-m", "gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "main:app"]
