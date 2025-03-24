resource "aws_s3_bucket" "website_s3_bucket" {
  bucket = local.website_s3_bucket_name
}
