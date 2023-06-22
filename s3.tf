/**
 * Static Assets S3 Bucket
 **/
locals {
  content_type_lookup = {
    css   = "text/css"
    woff2 = "font/woff2"
    js    = "text/javascript"
    svg   = "image/svg+xml"
    ico   = "image/x-icon"
    html  = "text/html"
    htm   = "text/html"
    json  = "application/json"
    png   = "image/png"
    jpg   = "image/jpeg"
    jpeg  = "image/jpeg"
  }
}


resource "aws_s3_bucket" "static_assets" {
  bucket = "${var.prefix}-static-assets"
}

resource "aws_s3_bucket_policy" "static_assets" {
  bucket = aws_s3_bucket.static_assets.bucket
  policy = data.aws_iam_policy_document.read_static_bucket.json
}

resource "aws_s3_bucket_versioning" "static_assets" {
  bucket = aws_s3_bucket.static_assets.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "static_assets" {
  depends_on = [aws_s3_bucket_versioning.static_assets]
  bucket     = aws_s3_bucket.static_assets.bucket

  rule {
    id     = "clear-versioned-assets"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }
  }
}


resource "aws_cloudfront_origin_access_identity" "static_assets" {
  comment = "CloudFront OAI for Static Assets S3 Bucket"
}

data "aws_iam_policy_document" "read_static_bucket" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject*"]
    resources = ["${aws_s3_bucket.static_assets.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.static_assets.iam_arn]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.static_assets.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.static_assets.iam_arn]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.static_assets.arn, "${aws_s3_bucket.static_assets.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [module.server_function.lambda_function_role_arn]
    }
  }
}

# Unhashed Files
resource "aws_s3_object" "static_files" {
  for_each = fileset("${abspath(var.opennext_build_path)}/assets", "**")

  bucket = aws_s3_bucket.static_assets.bucket
  key    = "assets/${each.value}"
  source = "${abspath(var.opennext_build_path)}/assets/${each.value}"
  etag   = filemd5("${abspath(var.opennext_build_path)}/assets/${each.value}")

  cache_control = length(regexall(".*(_next).*$", each.value)) > 0 ? "public,max-age=31536000,immutable" : "public,max-age=0,s-maxage=31536000,must-revalidate"

  content_type = lookup(local.content_type_lookup, split(".", each.value)[length(split(".", each.value)) - 1], "text/plain")
}

# Hashed Files
# resource "aws_s3_object" "hashed_static_files" {
#   for_each = fileset("${abspath(var.opennext_build_path)}/assets/_next/", "**")

#   bucket        = aws_s3_bucket.static_assets.bucket
#   key           = "assets/_next/${each.value}"
#   source        = "${abspath(var.opennext_build_path)}/assets/_next/${each.value}"
#   etag          = filemd5("${abspath(var.opennext_build_path)}/assets/_next/${each.value}")
#   cache_control = length(regexall( )) 
#   content_type  = lookup(local.content_type_lookup, split(".", each.value)[length(split(".", each.value)) - 1], "text/plain")
# }

# Cached Files
resource "aws_s3_object" "cached_files" {
  for_each = fileset("${abspath(var.opennext_build_path)}/cache/", "**")

  bucket       = aws_s3_bucket.static_assets.bucket
  key          = "cache/${each.value}"
  source       = "${abspath(var.opennext_build_path)}/cache/${each.value}"
  etag         = filemd5("${abspath(var.opennext_build_path)}/cache/${each.value}")
  content_type = lookup(local.content_type_lookup, split(".", each.value)[length(split(".", each.value)) - 1], "text/plain")
}

