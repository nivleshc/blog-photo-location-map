resource "aws_api_gateway_rest_api" "photo_location_map" {
  name        = "${local.api_gateway_rest_api_name_prefix}-api-gw"
  description = "API Gateway to front lambdas used to plot photo locations on a map"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

## expose fetch-objects lambda via API Gateway
# Allow API Gateway to invoke the fetch-object lambda function
resource "aws_lambda_permission" "apigw_invoke_fetch_object_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_object_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.photo_location_map.execution_arn}/*/*"
}

# create the resource for fetching object
resource "aws_api_gateway_resource" "fetch_object" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id
  parent_id   = aws_api_gateway_rest_api.photo_location_map.root_resource_id
  path_part   = local.api_gateway_fetch_object_path
}

# Create the method on the fetch resource that accepts GET method
resource "aws_api_gateway_method" "fetch_object_get" {
  rest_api_id   = aws_api_gateway_rest_api.photo_location_map.id
  resource_id   = aws_api_gateway_resource.fetch_object.id
  http_method   = "GET"
  authorization = "NONE"
}

# Set up the integration between API Gateway and the fetch-object Lambda function
resource "aws_api_gateway_integration" "fetch_object" {
  rest_api_id             = aws_api_gateway_rest_api.photo_location_map.id
  resource_id             = aws_api_gateway_resource.fetch_object.id
  http_method             = aws_api_gateway_method.fetch_object_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.fetch_object_lambda.invoke_arn
}

# Create CORS for fetch-object using OPTIONS method
resource "aws_api_gateway_method" "fetch_object_options" {
  rest_api_id   = aws_api_gateway_rest_api.photo_location_map.id
  resource_id   = aws_api_gateway_resource.fetch_object.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Set up a MOCK integration for the OPTIONS method.
resource "aws_api_gateway_integration" "fetch_object_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id
  resource_id = aws_api_gateway_resource.fetch_object.id
  http_method = aws_api_gateway_method.fetch_object_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Define the method response for OPTIONS, including CORS headers.
resource "aws_api_gateway_method_response" "fetch_object_options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id
  resource_id = aws_api_gateway_resource.fetch_object.id
  http_method = aws_api_gateway_method.fetch_object_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Configure the integration response for OPTIONS to set the CORS headers.
resource "aws_api_gateway_integration_response" "fetch_object_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id
  resource_id = aws_api_gateway_resource.fetch_object.id
  http_method = aws_api_gateway_method.fetch_object_options.http_method
  status_code = aws_api_gateway_method_response.fetch_object_options_method_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS,PUT,PATCH,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

## expose upload-photo lambda via API Gateway
# Allow API Gateway to invoke the upload-photo lambda function
resource "aws_lambda_permission" "apigw_invoke_upload_photo_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_photo_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.photo_location_map.execution_arn}/*/*"
}

# create the resource for uploading photo
resource "aws_api_gateway_resource" "upload_photo" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id
  parent_id   = aws_api_gateway_rest_api.photo_location_map.root_resource_id
  path_part   = local.api_gateway_upload_photo_path
}

# Create the method on the upload photo resource that uses POST method
resource "aws_api_gateway_method" "upload_photo_post" {
  rest_api_id   = aws_api_gateway_rest_api.photo_location_map.id
  resource_id   = aws_api_gateway_resource.upload_photo.id
  http_method   = "POST"
  authorization = "NONE"
}

# Set up the integration between API Gateway and the upload photo Lambda function
resource "aws_api_gateway_integration" "upload_photo" {
  rest_api_id             = aws_api_gateway_rest_api.photo_location_map.id
  resource_id             = aws_api_gateway_resource.upload_photo.id
  http_method             = aws_api_gateway_method.upload_photo_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.upload_photo_lambda.invoke_arn
}

# Create CORS for upload-photo using OPTIONS method
resource "aws_api_gateway_method" "upload_photo_options" {
  rest_api_id   = aws_api_gateway_rest_api.photo_location_map.id
  resource_id   = aws_api_gateway_resource.upload_photo.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Set up a MOCK integration for the OPTIONS method.
resource "aws_api_gateway_integration" "upload_photo_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id
  resource_id = aws_api_gateway_resource.upload_photo.id
  http_method = aws_api_gateway_method.upload_photo_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Define the method response for OPTIONS, including CORS headers.
resource "aws_api_gateway_method_response" "upload_photo_options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id
  resource_id = aws_api_gateway_resource.upload_photo.id
  http_method = aws_api_gateway_method.upload_photo_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Configure the integration response for OPTIONS to set the CORS headers.
resource "aws_api_gateway_integration_response" "upload_photo_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id
  resource_id = aws_api_gateway_resource.upload_photo.id
  http_method = aws_api_gateway_method.upload_photo_options.http_method
  status_code = aws_api_gateway_method_response.upload_photo_options_method_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS,PUT,PATCH,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

## expose regenerate-map lambda via API Gateway
# Allow API Gateway to invoke the regenerate-map lambda function
resource "aws_lambda_permission" "apigw_invoke_regenerate_map_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.regenerate_map_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.photo_location_map.execution_arn}/*/*"
}

# create the resource for regenerating map
resource "aws_api_gateway_resource" "regenerate_map" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id
  parent_id   = aws_api_gateway_rest_api.photo_location_map.root_resource_id
  path_part   = local.api_gateway_regenerate_map_path
}

# Create the method on the regenerate map resource that uses POST method
resource "aws_api_gateway_method" "regenerate_map_post" {
  rest_api_id   = aws_api_gateway_rest_api.photo_location_map.id
  resource_id   = aws_api_gateway_resource.regenerate_map.id
  http_method   = "POST"
  authorization = "NONE"
}

# Set up the integration between API Gateway and the regenerate map Lambda function
resource "aws_api_gateway_integration" "regenerate_map" {
  rest_api_id             = aws_api_gateway_rest_api.photo_location_map.id
  resource_id             = aws_api_gateway_resource.regenerate_map.id
  http_method             = aws_api_gateway_method.regenerate_map_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.regenerate_map_lambda.invoke_arn
}

# Create CORS for regenerate-map using OPTIONS method
resource "aws_api_gateway_method" "regenerate_map_options" {
  rest_api_id   = aws_api_gateway_rest_api.photo_location_map.id
  resource_id   = aws_api_gateway_resource.regenerate_map.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Set up a MOCK integration for the OPTIONS method.
resource "aws_api_gateway_integration" "regenerate_map_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id
  resource_id = aws_api_gateway_resource.regenerate_map.id
  http_method = aws_api_gateway_method.regenerate_map_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Define the method response for OPTIONS, including CORS headers.
resource "aws_api_gateway_method_response" "regenerate_map_options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id
  resource_id = aws_api_gateway_resource.regenerate_map.id
  http_method = aws_api_gateway_method.regenerate_map_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Configure the integration response for OPTIONS to set the CORS headers.
resource "aws_api_gateway_integration_response" "regenerate_map_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id
  resource_id = aws_api_gateway_resource.regenerate_map.id
  http_method = aws_api_gateway_method.regenerate_map_options.http_method
  status_code = aws_api_gateway_method_response.regenerate_map_options_method_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS,PUT,PATCH,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Deploy the API Gateway
resource "aws_api_gateway_deployment" "photo_location_map_deployment" {
  rest_api_id = aws_api_gateway_rest_api.photo_location_map.id

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.fetch_object,
    aws_api_gateway_integration.upload_photo,
    aws_api_gateway_integration.regenerate_map
  ]
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.photo_location_map_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.photo_location_map.id
  stage_name    = local.api_gateway_stage_name

  depends_on = [
    aws_api_gateway_integration.fetch_object,
    aws_api_gateway_integration.upload_photo,
    aws_api_gateway_integration.regenerate_map
  ]
}

output "api_gw_invoke_url" {
  description = "The API Gateway Stage Invoke URL"
  value       = aws_api_gateway_stage.stage.invoke_url
}
