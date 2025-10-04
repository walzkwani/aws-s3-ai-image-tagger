![AWS](https://img.shields.io/badge/AWS-Lambda-orange?logo=amazon-aws)
![Python](https://img.shields.io/badge/Python-3.9+-blue?logo=python)
![Terraform](https://img.shields.io/badge/Terraform-IaC-purple?logo=terraform)
![Bedrock](https://img.shields.io/badge/Amazon-Bedrock-orange)
![License](https://img.shields.io/badge/License-MIT-green)

# AWS S3 AI Image Tagger

Automatically generate AI-powered captions and tags for images uploaded to Amazon S3 using Amazon Bedrock's Claude multimodal model.

## Overview

This serverless application monitors an S3 bucket for new images, analyzes them using Amazon Bedrock's Claude vision capabilities, and automatically generates descriptive metadata including captions and tags. The metadata is stored as JSON files and applied as S3 object tags for easy searchability.

## Architecture

```
┌─────────────┐
│   Upload    │
│   Image     │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│  S3 Bucket          │
│  incoming/          │
└──────┬──────────────┘
       │ (S3 Event)
       ▼
┌─────────────────────┐
│  Lambda Function    │
│  - Get Image        │
│  - Call Bedrock     │
│  - Generate Tags    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Amazon Bedrock     │
│  (Claude Vision)    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────────────────┐
│  S3 Outputs                     │
│  - metadata/<file>.json         │
│  - S3 Object Tags Applied       │
└─────────────────────────────────┘
```

## Features

- **Automated Image Analysis**: Automatically processes images uploaded to the `incoming/` folder
- **AI-Powered Tagging**: Uses Amazon Bedrock's Claude multimodal model for intelligent image understanding
- **Metadata Storage**: Generates structured JSON metadata with captions and tags
- **S3 Object Tagging**: Applies tags directly to S3 objects for enhanced searchability
- **Infrastructure as Code**: Complete Terraform configuration for easy deployment
- **Serverless Architecture**: Cost-effective, pay-per-use Lambda-based solution

## Prerequisites

- AWS Account with appropriate permissions
- Terraform installed (v1.0+)
- Python 3.9 or later
- AWS CLI configured
- Access to Amazon Bedrock (Claude model enabled in your region)

## Setup

### 1. Configure Variables

Edit the Terraform variables in `infra/variables.tf`:

```hcl
variable "bucket_name" {
  description = "S3 bucket name for image storage"
  default     = "my-image-tagger-bucket"
}

variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "bedrock_model_id" {
  description = "Bedrock model ID"
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}
```

### 2. Package the Lambda Function

```bash
cd lambda
pip install -r requirements.txt -t .
zip -r ../dist/lambda.zip .
cd ..
```

### 3. Deploy Infrastructure

```bash
cd infra
terraform init
terraform apply
```

Review the planned changes and type `yes` to confirm.

### 4. Test the Application

Upload an image to the `incoming/` folder:

```bash
aws s3 cp test-image.jpg s3://your-bucket-name/incoming/
```

Check the results:

```bash
# View metadata file
aws s3 cp s3://your-bucket-name/metadata/test-image.json -

# View S3 object tags
aws s3api get-object-tagging --bucket your-bucket-name --key incoming/test-image.jpg
```

## How It Works

1. **Image Upload**: User uploads an image to `s3://bucket/incoming/`
2. **Event Trigger**: S3 event notification triggers the Lambda function
3. **Image Retrieval**: Lambda retrieves the image from S3
4. **AI Analysis**: Image is sent to Amazon Bedrock (Claude) for analysis
5. **Metadata Generation**: Claude generates a descriptive caption and relevant tags
6. **Storage**: 
   - Metadata is saved as JSON to `s3://bucket/metadata/<filename>.json`
   - Tags are applied to the original S3 object

## Example Output

**Input**: `vacation-photo.jpg`

**Metadata JSON** (`metadata/vacation-photo.json`):
```json
{
  "filename": "vacation-photo.jpg",
  "caption": "A scenic beach sunset with palm trees and golden sand",
  "tags": ["beach", "sunset", "tropical", "vacation", "nature", "ocean"],
  "timestamp": "2025-10-03T10:30:00Z",
  "model": "anthropic.claude-3-sonnet-20240229-v1:0"
}
```

**S3 Object Tags**:
- `ai-caption`: "A scenic beach sunset with palm trees and golden sand"
- `ai-tag-1`: "beach"
- `ai-tag-2`: "sunset"
- `ai-tag-3`: "tropical"

## Cost Considerations

Costs are minimal for light usage:

- **Lambda**: Free tier includes 1M requests/month, then $0.20 per 1M requests
- **S3**: Standard storage pricing (first 50 TB: $0.023/GB)
- **Amazon Bedrock**: Pay per request (varies by model, typically $0.003-0.015 per image)

**Estimated cost for 100 images/month**: ~$1-2 USD

## Security Best Practices

### Enable S3 Block Public Access

```bash
aws s3api put-public-access-block \
  --bucket your-bucket-name \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### (Optional) Enable KMS Encryption

Update `infra/main.tf` to add server-side encryption:

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  bucket = aws_s3_bucket.image_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
  }
}
```

### Use IAM Roles with Least Privilege

The Lambda function uses an IAM role with only the necessary permissions:
- Read access to `incoming/` folder
- Write access to `metadata/` folder
- Bedrock invocation permissions
- CloudWatch Logs permissions

## Supported Image Formats

- JPEG/JPG
- PNG
- GIF
- WebP
- BMP

## Customization

### Modify the Prompt

Edit `lambda/handler.py` to customize how Claude analyzes images:

```python
prompt = """Analyze this image and provide:
1. A detailed caption (20-30 words)
2. 5-10 relevant tags
3. The dominant colors
4. Any text visible in the image

Return as JSON."""
```

### Adjust Tag Limits

Modify the number of S3 object tags (AWS limit: 10 tags per object) in the Lambda handler.

## Troubleshooting

### Lambda Timeout
Increase timeout in `infra/main.tf`:
```hcl
timeout = 60  # seconds
```

### Memory Issues
Increase memory in `infra/main.tf`:
```hcl
memory_size = 512  # MB
```

### Bedrock Access Denied
Ensure Bedrock model access is enabled in your AWS region through the AWS Console.

## Cleanup

To remove all resources:

```bash
cd infra
terraform destroy
```

**Note**: This will delete the S3 bucket and all images. Backup important data first.

## Contributing

Contributions are welcome! Please submit pull requests or open issues for bugs and feature requests.

## License

MIT License - see LICENSE file for details

## Related Projects

- [azure-blob-ai-doc-summarizer](https://github.com/jmragsdale/azure-blob-ai-doc-summarizer) - Similar serverless AI document processing for Azure

## Acknowledgments

- Powered by [Amazon Bedrock](https://aws.amazon.com/bedrock/) and Claude
- Infrastructure managed with [Terraform](https://www.terraform.io/)
