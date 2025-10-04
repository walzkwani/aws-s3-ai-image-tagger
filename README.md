# S3 AI Image-Tagger (Bedrock + S3 + Lambda)

Drop an image into `s3://<bucket>/incoming/…`. A Lambda triggers, sends the image to **Amazon Bedrock (Claude multimodal)** for a caption + tags, then writes a `metadata/<file>.json` back to S3 and applies S3 object tags.

## Quick start
1. Edit Terraform variables in `infra/variables.tf` (bucket name, region, model id).
2. Zip the lambda: `cd lambda && pip install -r requirements.txt -t . && zip -r ../dist/lambda.zip .`
3. `cd infra && terraform init && terraform apply`
4. Upload an image to `incoming/` and check `metadata/`.

> Costs: pennies at light usage. Enable S3 Block Public Access and (optionally) KMS.

