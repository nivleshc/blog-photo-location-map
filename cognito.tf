##############################################
# Cognito User Pool for authenticating users
##############################################

resource "aws_cognito_user_pool" "user_pool" {
  name = local.cognito_user_pool_name

  # Customize password policy, MFA, etc., as needed
  password_policy {
    minimum_length    = local.cognito_password_policy.minimum_length
    require_uppercase = local.cognito_password_policy.require_uppercase
    require_lowercase = local.cognito_password_policy.require_lowercase
    require_numbers   = local.cognito_password_policy.require_numbers
    require_symbols   = local.cognito_password_policy.require_symbols
  }

  auto_verified_attributes = ["email"]

  # (Optional) Enable advanced security features
  mfa_configuration = local.cognito_mfa_configuration
}

##########################################################
# Cognito User Pool Client for application integration
##########################################################

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name                         = local.cognito_user_pool_client_name
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["COGNITO"]

  # Do not generate a client secret for browser-based apps
  generate_secret = false

  # Allowed OAuth flows and scopes for the hosted UI.
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  callback_urls = [
    "${aws_api_gateway_stage.stage.invoke_url}/fetch-object${local.cognito_callback_url_suffix}" # URL where Cognito should redirect after login
  ]

  logout_urls = [
    "${aws_api_gateway_stage.stage.invoke_url}/fetch-object${local.cognito_logout_url_suffix}" # URL to redirect after logout
  ]

  depends_on = [aws_api_gateway_stage.stage]
}

##############################################
# Cognito User Pool Domain for the hosted UI
##############################################

resource "aws_cognito_user_pool_domain" "user_pool_domain" {
  domain       = local.cognito_user_pool_domain # Must be globally unique
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

output "cognito_ui_url" {
  value      = "https://${aws_cognito_user_pool.user_pool.domain}.auth.${local.region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.user_pool_client.id}&response_type=code&scope=openid&redirect_uri=${tolist(aws_cognito_user_pool_client.user_pool_client.callback_urls)[0]}"
  depends_on = [aws_cognito_user_pool.user_pool]
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.user_pool_client.id
}
