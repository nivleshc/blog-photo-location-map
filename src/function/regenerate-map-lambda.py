import os
import io
import csv
import boto3
import json
import folium
import jwt
from jwt import PyJWKClient
from PIL import Image, ExifTags

def lambda_handler(event, context):

  # retrieve environmental variables
  bucket_name = os.environ.get('BUCKET_NAME')           # this contains the csv that has info about all the photos 
  csv_file_key = os.environ.get('CSV_FILE_KEY')         # name of the csv file, including path, that contains info about all the photos
  photo_location_map_filename = os.environ.get('PHOTO_LOCATION_MAP_FILENAME') # name to use for the photo location map
  cognito_pool_id = os.environ.get('COGNITO_POOL_ID')   # Cognito User Pool ID used for authentication
  cognito_region = os.environ.get('COGNITO_REGION')     # Cognito region

  # first authenticate the request
  # Build the issuer URL for the Cognito user pool
  cognito_issuer = f"https://cognito-idp.{cognito_region}.amazonaws.com/{cognito_pool_id}"

  # URL for the JWKS (public keys) used to validate tokens
  jwks_url = f"{cognito_issuer}/.well-known/jwks.json"
  jwks_client = PyJWKClient(jwks_url)
  
  local_photo_location_map_filename = f"/tmp/{photo_location_map_filename}" # the map will be generate and stored locally, then uploaded to s3

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

  # generate the map using the information stored in the csv file
  s3 = boto3.client('s3')

  try:
    response = s3.get_object(Bucket=bucket_name, Key=csv_file_key)
    content = response['Body'].read().decode('utf-8')

    csv_file = io.StringIO(content)
    reader = csv.DictReader(csv_file)

    images = []
    for row in reader:
      images.append({
        'name': row.get('name'),
        'user_id': row.get('user_id'),
        'timestamp': row.get('timestamp'),
        'gps_latitude': row.get('gps_latitude'),
        'gps_longitude': row.get('gps_longitude'),
        'url': row.get('url')
      })

    print(f"Extracted images info:{images}")

    # generate the map, anchor it on the first photo record
    m = folium.Map(location=[images[0]['gps_latitude'],images[0]['gps_longitude']], zoom_start=2)
    
    for record in images:
      try:
        lat = float(record['gps_latitude'])
        long = float(record['gps_longitude'])
      except Exception as e:
        print(f"Error converting coords to float lat:{record['gps_latitude']} long:{record['gps_longitude']}")

      popup_html = (
        f"<b>Date:</b> {record['timestamp']}<br/>"
        f"<b>Name:</b> {record['name']}<br/>"
        f"<b>User:</b> {record['user_id']}<br/>"
        f"<img src='{record['url']}' width='100'/><br/>"
        f"<a href='{record['url']}' target='_blank'>View Photo</a>"
      )

      tooltip_html = (
        f"<b>Date:</b> {record['timestamp']}<br/>"
        f"<b>Name:</b> {record['name']}<br/>"
        f"<b>User:</b> {record['user_id']}<br/>"
        f"<img src='{record['url']}' width='100'/><br/>"
      )

      folium.Marker(
        location=[lat, long],
        popup=popup_html,
        tooltip=tooltip_html,
        icon=folium.Icon(color='blue', icon='camera', prefix='fa')
      ).add_to(m)

  # except s3.exceptions.NoSuchKey:
  except Exception as e:
    # csv file doesn't exist. Generate a blank map
    print(f"csv file doesn't exist. Generating blank photo location map. Error:{e}")
    m = folium.Map()

  # save map to local file
  m.save(local_photo_location_map_filename)

  # transfer local map file to S3 bucket
  try:
    response = s3.upload_file(local_photo_location_map_filename, bucket_name, photo_location_map_filename)
    print(f"Photo location map successfully generated and uploaded to S3 bucket. Response:{response}")

    return {
      'statusCode': 200,
      'headers': {
        'Access-Control-Allow-Origin': '*'
      },
      'body': json.dumps(f"Photo location map successfully generated")
    }
  except Exception as e:
    print(f'Error uploading photo location map to s3 bucket:{e}')
    return {
      'statusCode': 500,
      'headers': {
        'Access-Control-Allow-Origin': '*'
      },
      'body': json.dumps(f"Error generating photo location map")
    }

def _access_denied(message):
  return {
    "statusCode": 403,
    "headers": {
      "Access-Control-Allow-Origin": "*"
    },
    "body": f"Access Denied: {message}"
  }
