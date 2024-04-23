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

variable "bucket_name" {
  description = "Name of the S3 bucket for storing Cost and Usage Reports."
}

variable "role_name" {
  description = "Name for the IAM Role"
}

resource "aws_s3_bucket" "digusher_s3_bucket" {
  bucket = var.bucket_name
  acl    = "private"
}

resource "aws_s3_bucket_policy" "digusher_s3_bucket_policy" {
  bucket = aws_s3_bucket.digusher_s3_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "billingreports.amazonaws.com"
        }
        Action    = [
          "s3:GetBucketAcl",
          "s3:GetBucketPolicy"
        ]
        Resource  = "${aws_s3_bucket.digusher_s3_bucket.arn}"
      },
      {
        Effect    = "Allow"
        Principal = {
          Service = "billingreports.amazonaws.com"
        }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.digusher_s3_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_cur_report_definition" "digusher_cost_and_usage_report" {
  report_name             = "DigiUsherCostAndUsageReport_${var.bucket_name}"
  time_unit               = "DAILY"
  format                  = "textORcsv"
  compression             = "ZIP"
  s3_bucket               = aws_s3_bucket.digusher_s3_bucket.bucket
  s3_region               = "us-east-1"
  s3_prefix               = "CUR/"
  additional_schema_elements = ["RESOURCES"]
  refresh_closed_reports  = true
  report_versioning       = "OVERWRITE_REPORT"
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
          Sid    = "DigiUsherOperations"
          Effect = "Allow"
          Action = [
            "s3:GetBucketPublicAccessBlock",
            "s3:GetBucketPolicyStatus",
            "s3:GetBucketTagging",
            "iam:GetAccessKeyLastUsed",
            "cloudwatch:GetMetricStatistics",
            "s3:GetBucketAcl",
            "ec2:Describe*",
            "s3:ListBucket",
            "s3:GetObject",
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

output "report_name" {
  description = "Report Name"
  value       = aws_cur_report_definition.digusher_cost_and_usage_report.id
}

output "bucket_name" {
  description = "Report Amazon S3 bucket name"
  value       = aws_s3_bucket.digusher_s3_bucket.bucket
}

output "s3_prefix" {
  description = "Report Path Prefix"
  value       = "CUR/"
}
