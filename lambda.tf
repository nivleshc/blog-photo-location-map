data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name = "${local.lambda_function_name_prefix}-lambda-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "logs:CreateLogGroup",
      "Resource": "arn:aws:logs:${local.region}:${local.account_id}:*"
    },
    {
      "Effect": "Allow",
      "Action": [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_name_prefix}-*:*"
    },
    {
      "Sid": "GetPutS3Objects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::${local.website_s3_bucket_name}/*"
    },
    {
      "Sid": "ListS3Objects",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::${local.website_s3_bucket_name}"
    }
  ]
}
EOF
}

# create IAM role for lambda
resource "aws_iam_role" "lambda_role" {
  name               = "${local.lambda_function_name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "attach_policy_to_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# create the CloudWatch Log Group beforehand so that we can set its retention period
resource "aws_cloudwatch_log_group" "fetch_object_lambda_loggroup" {
  name              = "/aws/lambda/${local.lambda_function_name_prefix}-fetch-object-lambda"
  retention_in_days = local.lambda_cloudwatch_log_group_retention
}

resource "aws_cloudwatch_log_group" "upload_photo_lambda_loggroup" {
  name              = "/aws/lambda/${local.lambda_function_name_prefix}-upload-photo-lambda"
  retention_in_days = local.lambda_cloudwatch_log_group_retention
}

resource "aws_cloudwatch_log_group" "regenerate_map_lambda_loggroup" {
  name              = "/aws/lambda/${local.lambda_function_name_prefix}-regenerate-map-lambda"
  retention_in_days = local.lambda_cloudwatch_log_group_retention
}

# zip the source files for lambda functions
data "archive_file" "fetch_object_lambda_src" {
  type        = "zip"
  source_file = "${path.module}/src/function/fetch-object-lambda.py"
  output_path = "${path.module}/src/function/fetch-object-lambda.zip"
}

data "archive_file" "upload_photo_lambda_src" {
  type        = "zip"
  source_file = "${path.module}/src/function/upload-photo-lambda.py"
  output_path = "${path.module}/src/function/upload-photo-lambda.zip"
}

data "archive_file" "regenerate_map_lambda_src" {
  type        = "zip"
  source_file = "${path.module}/src/function/regenerate-map-lambda.py"
  output_path = "${path.module}/src/function/regenerate-map-lambda.zip"
}

# create lambda layers
resource "aws_lambda_layer_version" "photo_location_map_layer" {
  filename    = "${path.module}/src/layers/layer-photo-location-map.zip"
  layer_name  = "layer_photo_location_map"
  description = "Lambda layer containing cffi cryptography PyJWT pillow folium python packages"

  compatible_runtimes = local.lambda_layer_compatibe_runtimes
  source_code_hash    = filebase64sha256("${path.module}/src/layers/layer-photo-location-map.zip")
}

resource "aws_lambda_function" "fetch_object_lambda" {
  filename      = data.archive_file.fetch_object_lambda_src.output_path
  function_name = "${local.lambda_function_name_prefix}-fetch-object-lambda"
  timeout       = local.lambda_function_timeout
  role          = aws_iam_role.lambda_role.arn
  handler       = "fetch-object-lambda.lambda_handler"

  source_code_hash = data.archive_file.fetch_object_lambda_src.output_base64sha256

  runtime = local.lambda_runtime
  layers  = [aws_lambda_layer_version.photo_location_map_layer.arn]

  environment {
    variables = {
      BUCKET_NAME     = local.website_s3_bucket_name
      COGNITO_POOL_ID = aws_cognito_user_pool.user_pool.id
      COGNITO_REGION  = local.region
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.fetch_object_lambda_loggroup
  ]
}

resource "aws_lambda_function" "upload_photo_lambda" {
  filename      = data.archive_file.upload_photo_lambda_src.output_path
  function_name = "${local.lambda_function_name_prefix}-upload-photo-lambda"
  timeout       = local.lambda_function_timeout
  role          = aws_iam_role.lambda_role.arn
  handler       = "upload-photo-lambda.lambda_handler"

  source_code_hash = data.archive_file.upload_photo_lambda_src.output_base64sha256

  runtime = local.lambda_runtime
  layers  = [aws_lambda_layer_version.photo_location_map_layer.arn]

  environment {
    variables = {
      BUCKET_NAME            = local.website_s3_bucket_name
      CSV_FILE_KEY           = local.csv_file_key
      IMAGES_FOLDER_KEY      = local.images_folder_key
      PRESIGN_URL_EXPIRATION = local.presign_url_expiration
      COGNITO_POOL_ID        = aws_cognito_user_pool.user_pool.id
      COGNITO_REGION         = local.region
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.upload_photo_lambda_loggroup
  ]
}

resource "aws_lambda_function" "regenerate_map_lambda" {
  filename      = data.archive_file.regenerate_map_lambda_src.output_path
  function_name = "${local.lambda_function_name_prefix}-regenerate-map-lambda"
  timeout       = local.lambda_function_timeout
  role          = aws_iam_role.lambda_role.arn
  handler       = "regenerate-map-lambda.lambda_handler"

  source_code_hash = data.archive_file.regenerate_map_lambda_src.output_base64sha256

  runtime = local.lambda_runtime
  layers  = [aws_lambda_layer_version.photo_location_map_layer.arn]

  environment {
    variables = {
      BUCKET_NAME                 = local.website_s3_bucket_name
      COGNITO_POOL_ID             = aws_cognito_user_pool.user_pool.id
      COGNITO_REGION              = local.region
      CSV_FILE_KEY                = local.csv_file_key
      PHOTO_LOCATION_MAP_FILENAME = local.photo_location_map_filename
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.regenerate_map_lambda_loggroup
  ]
}
