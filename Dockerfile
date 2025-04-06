# Use official Python image
FROM python:3.10-slim

# Set work directory
WORKDIR /app

# Copy app code
COPY app.py .

# Expose port Flask will run on
EXPOSE 5000

# Run the app
CMD ["python", "app.py"]
