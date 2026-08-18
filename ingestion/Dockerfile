# Use a slim Python base image (small, fast, supported)
FROM python:3.11.8-slim

# Prevent Python from writing .pyc files
ENV PYTHONDONTWRITEBYTECODE=1

# Ensure logs appear immediately in Cloud Logging
ENV PYTHONUNBUFFERED=1

# Set working directory inside the container
WORKDIR /app

# Copy dependency definitions first (better layer caching)
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your application code
COPY . .

# Command Cloud Run will execute
CMD ["python", "main.py"]