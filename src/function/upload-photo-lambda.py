import os
import json
import base64
import boto3
import csv
import io
import jwt
from jwt import PyJWKClient
from PIL import Image, ExifTags

def lambda_handler(event, context):
  try:
    # Environment variables
    bucket_name = os.environ.get('BUCKET_NAME')
    csv_file_key = os.environ.get('CSV_FILE_KEY')           # name of the csv file, including path, that contains info about all the photos
    images_folder_key = os.environ.get('IMAGES_FOLDER_KEY') # folder inside which images will be stored
    presign_url_expiration = os.environ.get('PRESIGN_URL_EXPIRATION') # how long after (in seconds) that the presign url expires
    cognito_pool_id = os.environ.get('COGNITO_POOL_ID')   # Cognito User Pool ID used for authentication
    cognito_region = os.environ.get('COGNITO_REGION')     # Cognito region

    # first authenticate the request
    # Build the issuer URL for the Cognito user pool
    cognito_issuer = f"https://cognito-idp.{cognito_region}.amazonaws.com/{cognito_pool_id}"

    # URL for the JWKS (public keys) used to validate tokens
    jwks_url = f"{cognito_issuer}/.well-known/jwks.json"
    jwks_client = PyJWKClient(jwks_url)
    
    # authenticate this session
    headers = event.get('headers', {})
    auth_header = headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
      return _access_denied("Missing or malformed Authorization header.")

    token = auth_header.split(' ')[1]

    # validate the JWT token using Cognito's JWKS
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

    # at this point, the user has been successfully authenticated.
    # we can now proceed.

    # Parse the JSON payload from the API Gateway event body
    body = json.loads(event['body'])
    filename = body['filename']
    username = body['username']
    date_taken = body['date_taken']
    gps_lat = body['gps_lat']
    gps_long = body['gps_long']
    file_content_b64 = body['file_content']
    content_type = body['content_type']

    # if latitude and longitude values are not provided, set them to a default value
    # somewhere in Antarctica

    if (gps_lat == ''):
      print(f"No gps_lat found. Setting it to -130")
      gps_lat = '-130.0'
    
    if (gps_long == ''):
      print(f"No gps_long found. Setting it to 180")
      gps_long = '180.0'

    print(f'content_type:{content_type}')  

    # Decode file content from base64
    file_bytes = base64.b64decode(file_content_b64)
    
    # Upload the file to S3
    s3 = boto3.client('s3')

    file_path = images_folder_key + filename
    s3.put_object(Bucket=bucket_name, Key=file_path, Body=file_bytes)
    
    # Generate a pre-signed URL for the photo
    url = s3.generate_presigned_url(
      'get_object',
      Params={
        'Bucket': bucket_name,
        'Key': file_path,
        'ResponseContentType': content_type
        },
      ExpiresIn=presign_url_expiration
    )
    
    # Prepare the new row for the CSV file
    new_row = [filename, username, date_taken, gps_lat, gps_long, url]
      
    # Load the existing CSV data from CSV_BUCKET/CSV_KEY if it exists
    try:
      response = s3.get_object(Bucket=bucket_name, Key=csv_file_key)
      csv_content = response['Body'].read().decode('utf-8')
      csv_file = io.StringIO(csv_content)
      reader = list(csv.reader(csv_file))
      header = reader[0] if reader else ["name", "user_id", "timestamp", "gps_latitude", "gps_longitude", "url"]
      rows = reader[1:] if len(reader) > 1 else []
    except s3.exceptions.NoSuchKey:
      # If CSV does not exist, create header and empty list of rows.
      header = ["name", "user_id", "timestamp", "gps_latitude", "gps_longitude", "url"]
      rows = []
      
    # Append the new row
    rows.append(new_row)
    
    # Write the updated CSV content to a string
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(header)
    for row in rows:
      writer.writerow(row)
    updated_csv = output.getvalue()
    
    # Upload the updated CSV back to S3
    s3.put_object(Bucket=bucket_name, Key=csv_file_key, Body=updated_csv.encode('utf-8'))
      
    return {
      'statusCode': 200,
      'headers': {
        'Access-Control-Allow-Origin': '*'
      },
      'body': json.dumps({'message': 'File uploaded successfully.'})
    }
  except Exception as e:
    print("Error:", e)
    return {
      'statusCode': 500,
      'headers': {
        'Access-Control-Allow-Origin': '*'
      },
      'body': json.dumps({'error': str(e)})
    }

def _access_denied(message):
  return {
    "statusCode": 403,
    "headers": {
      "Access-Control-Allow-Origin": "*"
    },
    "body": f"Access Denied: {message}"
  }
