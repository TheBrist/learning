import os
import base64
import requests
import azure.functions as func
import tempfile

cert_str_b64 = os.environ["CERTIFICATE"]
cert_str = base64.b64decode(cert_str_b64).decode("utf-8")
gcp_url = os.environ.get("GCP_LB_URL")

tmp_cert_file = tempfile.NamedTemporaryFile(suffix=".pem", delete=False)
cert_file_path = ""
with open(tmp_cert_file.name, 'w') as f:
    f.write(cert_str)
    f.seek(0)
    f.flush()
    cert_file_path = f.name

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="HTTPtrigger", methods=["POST"])
def main(req: func.HttpRequest) -> func.HttpResponse:
    try:
        request_body = req.get_json()
    except ValueError:
        return func.HttpResponse(
            "Invalid JSON payload",
            status_code=400
        )
    
    try:
        response = requests.post(gcp_url, json=request_body, verify=False)
        
        if response.status_code == 200:

            return func.HttpResponse(
                f"Forwarded to GCP !!!!",
                status_code=200
            )
        else:
            return func.HttpResponse(
                f"Failed to forward request to GCP",
                status_code=500
            )
    
    except requests.exceptions.RequestException as e:
        return func.HttpResponse(
            f"Error forwarding request to GCP ",
            status_code=500
        )
