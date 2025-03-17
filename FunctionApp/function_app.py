import os
import requests
import azure.functions as func

# def forward_request(req: func.HttpRequest) -> func.HttpResponse:
#     try:
#         gcp_token = os.environ.get("GCP_ACCESS_TOKEN")  
        
#         outbound_headers = {
#             key: value 
#             for key, value in req.headers.items() 
#             if key.lower() not in ["host", "authorization"]
#         }
#         outbound_headers["Authorization"] = f"Bearer {gcp_token}"

#         response = requests.post(os.environ.get("GCP_LB_URL"), headers=outbound_headers, data=req.get_body())

#         return func.HttpResponse(response.text, status_code=response.status_code)

#     except Exception as e:
#         return func.HttpResponse(f"Error: {str(e)}", status_code=500)

# app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# @app.route(route="HTTPtrigger", methods=["POST"])
# def main(req: func.HttpRequest) -> func.HttpResponse:
#     return forward_request(req)

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

    gcp_url = os.environ.get("GCP_LB_URL")

    try:
        response = requests.post(gcp_url, json=request_body)
        
        if response.status_code == 200:
            return func.HttpResponse(
                "Request forwarded successfully to GCP",
                status_code=200
            )
        else:
            return func.HttpResponse(
                "Failed to forward request to GCP",
                status_code=500
            )
    
    except requests.exceptions.RequestException as e:
        return func.HttpResponse(
            "Error forwarding request to GCP",
            status_code=500
        )
