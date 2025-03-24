# create the webpage that will be used to interact with this solution
resource "local_file" "index_html" {
  content = templatefile("${path.module}/tpl/index.tftpl",
    { user_pool_id              = aws_cognito_user_pool.user_pool.id,
      client_id                 = aws_cognito_user_pool_client.user_pool_client.id,
      api_gw_fetch_object_url   = "${aws_api_gateway_stage.stage.invoke_url}/${local.api_gateway_fetch_object_path}${local.cognito_callback_url_suffix}",
      api_gw_upload_photo_url   = "${aws_api_gateway_stage.stage.invoke_url}/${local.api_gateway_upload_photo_path}${local.cognito_callback_url_suffix}",
      api_gw_regenerate_map_url = "${aws_api_gateway_stage.stage.invoke_url}/${local.api_gateway_regenerate_map_path}${local.cognito_callback_url_suffix}"
  })
  filename = "${path.module}/${local.local_webpage_path}"

  depends_on = [aws_cognito_user_pool_domain.user_pool_domain]
}
