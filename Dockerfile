FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY agent ./agent
RUN mkdir -p /app/data && useradd -m appuser && chown -R appuser:appuser /app
USER appuser
CMD ["python", "-m", "agent.main"]
