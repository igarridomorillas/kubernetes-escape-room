FROM python:3.12-alpine3.20
WORKDIR /app
COPY app.py .
USER 65534:65534
EXPOSE 8080
CMD ["python", "-u", "app.py"]
