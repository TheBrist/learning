from flask import Flask, request
from google.cloud import storage
import os
import datetime
import json

app = Flask(__name__)
storage_client = storage.Client()
BUCKET_NAME = os.environ.get("BUCKET_NAME")

@app.route("/", methods=["POST"])
def forward_request():
    body_data = request.get_data(as_text=True)  #
    
    file_name = f"requests/{datetime.datetime.utcnow().isoformat().replace(':', '-')}.json"         
    
    bucket = storage_client.bucket(BUCKET_NAME)
    blob = bucket.blob(file_name)
    blob.upload_from_string(body_data, content_type="application/json")  

    print(f"File {file_name} uploaded to {BUCKET_NAME}.")
    
    return {"message": "Request body stored successfully", "file": file_name}, 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
