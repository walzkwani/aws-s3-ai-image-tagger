terraform {
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }
}
provider "aws" { region = var.region }

resource "aws_s3_bucket" "images" { bucket = var.bucket_name }
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.images.id
  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "lambda_trust" {
  statement { actions = ["sts:AssumeRole"]; principals { type = "Service" identifiers = ["lambda.amazonaws.com"] } }
}
resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version="2012-10-17", Statement=[
      {Effect="Allow", Action=["s3:GetObject","s3:PutObject","s3:PutObjectTagging"], Resource=["${aws_s3_bucket.images.arn}/*"]},
      {Effect="Allow", Action=["bedrock:InvokeModel"], Resource="*"},
      {Effect="Allow", Action=["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], Resource="*"}
    ]}
  )
}

resource "aws_lambda_function" "tagger" {
  function_name = "${var.project}-tagger"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.handler"
  runtime       = "python3.11"
  filename      = "${path.module}/../dist/lambda.zip"
  environment { variables = { AWS_REGION=var.region, MODEL_ID=var.model_id } }
}

resource "aws_s3_bucket_notification" "on_upload" {
  bucket = aws_s3_bucket.images.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.tagger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "incoming/"
  }
}
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tagger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.images.arn
}
