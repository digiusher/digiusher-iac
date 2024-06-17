terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.46.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

variable "role_name" {
  description = "Name for the IAM Role"
}

resource "aws_iam_role" "digusher_iam_role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::058264546051:root"
        }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "DigiUsherRolePolicy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "DigiUsherRecommendationsPermissions"
          Effect = "Allow"
          Action = [
            "s3:GetBucketPublicAccessBlock",
            "s3:GetBucketPolicyStatus",
            "s3:GetBucketTagging",
            "iam:GetAccessKeyLastUsed",
            "cloudwatch:GetMetricStatistics",
            "s3:GetBucketAcl",
            "ec2:Describe*",
            "s3:ListAllMyBuckets",
            "iam:ListUsers",
            "s3:GetBucketLocation",
            "iam:GetLoginProfile",
            "cur:DescribeReportDefinitions",
            "iam:ListAccessKeys"
          ]
          Resource = "*"
        }
      ]
    })
  }
}

output "iam_role_arn" {
  description = "Role ARN Value"
  value       = aws_iam_role.digusher_iam_role.arn
}
