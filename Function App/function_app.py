import os
import base64
import requests
import azure.functions as func
import tempfile
from pathlib import Path
import json
import google.auth.transport.requests
from google.auth import identity_pool
from google.oauth2 import service_account

CLIENT_CONFIG_JSON_PATH = "/home/site/wwwroot/clientLibraryConfig-azure.json"
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = CLIENT_CONFIG_JSON_PATH
os.environ["GOOGLE_CLOUD_PROJECT"] = "mod-gcp-mam-haf-netanel-01"

with open(CLIENT_CONFIG_JSON_PATH, "r") as f:
    client_config = json.load(f)

credentials = identity_pool.Credentials.from_info(client_config)
print(credentials.token)

request_obj = google.auth.transport.requests.Request()
credentials.refresh(request_obj)

request_body = {
    "message": "Hello from Azure VM using Workload Identity Federation!"
}

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="http_trigger", methods=["POST"])
def main(req: func.HttpRequest) -> func.HttpResponse:
    try:
        response = requests.post("https://34.0.66.120/", json=request_body, verify=False)
        if response.status_code == 200:
            print(f"Success! Response from GCP: {response.text} test: {credentials.token}")
        else:
            print(f"Request failed. Status: {response.status_code}, Response: {response.text} test: {credentials.token}")

    except requests.exceptions.RequestException as e:
        print(f"Request error: {e} test: {credentials.token}s")
