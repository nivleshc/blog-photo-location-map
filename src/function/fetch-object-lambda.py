import os
import json
import boto3
import urllib.request
import jwt
from jwt import PyJWKClient

# retrieve environment variables
s3_bucket = os.environ.get('BUCKET_NAME')             # S3 bucket that contains all the objects
cognito_pool_id = os.environ.get('COGNITO_POOL_ID')   # Cognito User Pool ID used for authentication
cognito_region = os.environ.get('COGNITO_REGION')     # Cognito region

# Build the issuer URL for the Cognito user pool
cognito_issuer = f"https://cognito-idp.{cognito_region}.amazonaws.com/{cognito_pool_id}"

# URL for the JWKS (public keys) used to validate tokens
jwks_url = f"{cognito_issuer}/.well-known/jwks.json"
jwks_client = PyJWKClient(jwks_url)

s3 = boto3.client('s3')

def lambda_handler(event, context):
  print("Received event:", json.dumps(event))

  # first authenticate the request
  # Expect the client to pass an Authorization header with a Bearer token
  headers = event.get('headers', {})
  auth_header = headers.get('Authorization', '')
  if not auth_header.startswith('Bearer '):
    return _access_denied("Missing or malformed Authorization header.")

  token = auth_header.split(' ')[1]

  # Validate the JWT token using Cognito's JWKS
  try:
    signing_key = jwks_client.get_signing_key_from_jwt(token)
    decoded = jwt.decode(
      token,
      signing_key.key,
      algorithms=["RS256"],
      issuer=cognito_issuer,
      options={"verify_aud": False}
    )
    username = decoded.get('username')
    print("Token decoded successfully:", decoded)
    print("Username:", username)
  except Exception as e:
    print("Token validation error:", str(e))
    return _access_denied("Invalid token.")

  # At this point, the user is authenticated.
  # we can now proceed.
  
  # find the key for the object that needs to be retrieved from the S3 bucket
  queryStringParameters = event.get("queryStringParameters", {})
  
  if queryStringParameters.get("filename").strip() != "": 
    file_key = queryStringParameters.get("filename").strip()
    print(f"Found query string parameters:{queryStringParameters} file_key:{file_key}")
  else:
    print("No query string parameters or filename found.")
    return {
      "statusCode": 404,
      "headers": {
        "Access-Control-Allow-Origin": "*"
      },
      "body": "No object name specified in query!."
    }

  # retrieve the object from S3 bucket and return it  
  try:
    s3_response = s3.get_object(Bucket=s3_bucket, Key=file_key)
    file_content = s3_response['Body'].read()
    content_type = s3_response.get('ContentType', 'text/html')
    print(f"Successfully returned file {file_key} from S3 Bucket={s3_bucket}")
    return {
      "statusCode": 200,
      "headers": {
        "Content-Type": content_type,
        "Access-Control-Allow-Origin": "*"
        },
      "body": file_content.decode('utf-8')  # Assumes text-based content
    }
  except Exception as e:
    print(f"Error fetching file {file_key} from S3 bucket {s3_bucket}. Error:{str(e)}")
    return {
      "statusCode": 404,
      "headers": {
        "Access-Control-Allow-Origin": "*"
      },
      "body": "File not found."
    }

def _access_denied(message):
  return {
    "statusCode": 403,
    "headers": {
      "Access-Control-Allow-Origin": "*"
    },
    "body": f"Access Denied: {message}"
  }
