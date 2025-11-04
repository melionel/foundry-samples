# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies from requirements.txt
RUN pip install -r requirements.txt

# Copy the migration script and supporting files
COPY v1_to_v2_migration.py .
COPY read_cosmos_data.py .

# Create a non-root user for security
RUN useradd -m -u 1000 migration && chown -R migration:migration /app

# Create Azure CLI directory with proper permissions for the migration user
RUN mkdir -p /home/migration/.azure && chown -R migration:migration /home/migration/.azure

# Switch to migration user
USER migration

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app
ENV AZURE_CONFIG_DIR=/home/migration/.azure

# Default command
ENTRYPOINT ["python", "v1_to_v2_migration.py"]
CMD ["--help"]