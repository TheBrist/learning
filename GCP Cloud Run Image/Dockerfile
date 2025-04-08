FROM python:3.10

WORKDIR /app.py
COPY . /app.py

RUN pip install flask google-cloud-storage

CMD ["python", "app.py"]