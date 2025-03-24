locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = "ap-southeast-2"

  lambda_function_name_prefix           = "photo-location-map"
  lambda_cloudwatch_log_group_retention = 7
  lambda_runtime                        = "python3.13"
  lambda_function_timeout               = 300 # in seconds
  lambda_handler                        = "lambda_function.lambda_handler"
  lambda_layer_compatibe_runtimes       = ["python3.13"]

  website_s3_bucket_name = "<my-photo-location-map-bucket>"

  api_gateway_rest_api_name_prefix = "photo-location-map"
  api_gateway_stage_name           = "prod"
  api_gateway_fetch_object_path    = "fetch-object"
  api_gateway_upload_photo_path    = "upload-photo"
  api_gateway_regenerate_map_path  = "regenerate-map"

  cognito_password_policy = {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }
  cognito_mfa_configuration     = "OFF"
  cognito_user_pool_name        = "photo-location-map-user-pool"
  cognito_user_pool_client_name = "photo-location-map-user-pool-client"
  cognito_user_pool_domain      = "photo-location-map-auth"
  cognito_callback_url_suffix   = "?filename=photo_location_map.html"
  cognito_logout_url_suffix     = "?filename=photo_location_map.html"

  # location relative to the terraform folder, where the local Photo Location Map webpage will
  # be stored
  local_webpage_path = "webfiles/index.html"

  # values used for photo location map
  csv_file_key                = "config/images.csv"
  images_folder_key           = "images/"
  photo_location_map_filename = "photo_location_map.html"
  presign_url_expiration      = 3600 # in seconds. Expiration time for the photo presign url
}
