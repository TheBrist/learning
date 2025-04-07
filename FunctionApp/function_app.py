import azure.functions as func
import os

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="http_trigger", methods=["POST"])
def main(req: func.HttpRequest) -> func.HttpResponse:
    try:
        GCP_AUDIENCE = os.environ.get("GCP_AUDIENCE")
        SUBJECT_TOKEN_TYPE = os.environ.get("SUBJECT_TOKEN_TYPE")
        TOKEN_URL = os.environ.get("TOKEN_URL")
        SERVICE_ACCOUNT_IMPERSONATION_URL = os.environ.get("SERVICE_ACCOUNT_IMPERSONATION_URL")
        CLOUD_RUN_URL = os.environ.get("CLOUD_RUN_URL")
        FORWARDING_IP = os.environ.get("FORWARDING_IP")
        
        try:
            identity_endpoint = os.environ.get("IDENTITY_ENDPOINT")
            identity_header = os.environ.get("IDENTITY_HEADER")
            if not identity_endpoint or not identity_header:
                return func.HttpResponse("Managed identity not configured", status_code=500)
            
            resource = "api://b723a5f3-fde9-455d-8867-e85ca2c1db1d"
            token_url_managed = f"{identity_endpoint}?api-version=2019-08-01&resource={resource}"
            
            metadata_response = requests.get(token_url_managed, headers={"X-IDENTITY-HEADER": identity_header}, timeout=10)
            
            if metadata_response.status_code != 200:
                return func.HttpResponse(f"Failed to get Azure token: {metadata_response.text}", status_code=500)
                
            azure_token = metadata_response.json().get("access_token")
            if not azure_token:
                return func.HttpResponse("No access token found in metadata response", status_code=500)
                
        except Exception as e:
            return func.HttpResponse(f"Error getting Azure token: {str(e)}", status_code=500)

        sts_request = {
            "audience": GCP_AUDIENCE,
            "grantType": "urn:ietf:params:oauth:grant-type:token-exchange",
            "requestedTokenType": "urn:ietf:params:oauth:token-type:access_token",
            "scope": "https://www.googleapis.com/auth/cloud-platform",
            "subjectTokenType": SUBJECT_TOKEN_TYPE,
            "subjectToken": azure_token
        }
        
        try:
            sts_response = requests.post(TOKEN_URL, json=sts_request, timeout=10)
            
            if sts_response.status_code != 200:
                return func.HttpResponse(f"Failed STS exchange: {sts_response.text}", status_code=500)
                
            sts_token = sts_response.json().get("access_token")
            if not sts_token:
                return func.HttpResponse("No access token found in STS response", status_code=500)
                
        except Exception as e:
            return func.HttpResponse(f"Error during STS exchange: {str(e)}", status_code=500)

        impersonation_request = {
            "audience": CLOUD_RUN_URL,
            "includeEmail": True
        }

        try:
            impersonation_response = requests.post(
                SERVICE_ACCOUNT_IMPERSONATION_URL,
                json=impersonation_request,
                headers={"Authorization": f"Bearer {sts_token}"},
                timeout=10
            )
            
            if impersonation_response.status_code != 200:
                return func.HttpResponse(f"Failed service account impersonation: {impersonation_response.text}", status_code=500)
                
            id_token = impersonation_response.json().get("token")
            if not id_token:
                return func.HttpResponse("No token found in impersonation response", status_code=500)
                
        except Exception as e:
            return func.HttpResponse(f"Error during service account impersonation: {str(e)}", status_code=500)

        headers = {
            "Authorization": f"Bearer {id_token}"
        }
        
        try:
            req_body = req.get_json()
            
            response = requests.post(
                FORWARDING_IP,
                json=req_body,
                headers=headers,
                verify=False, 
                timeout=10
            )
            
            return func.HttpResponse(
                body=response.text,
                status_code=response.status_code,
                mimetype="application/json"
            )
        except Exception as e:
            return func.HttpResponse(f"Error when calling GCP endpoint: {str(e)}", status_code=500)
            
    except Exception as e:
        return func.HttpResponse(f"Unhandled error: {str(e)}", status_code=500)
