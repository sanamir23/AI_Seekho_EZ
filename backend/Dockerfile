FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Cloud Run sets the PORT environment variable (default is 8080)
ENV PORT=8080

# Command to run the application
CMD uvicorn app.main:app --host 0.0.0.0 --port $PORT
