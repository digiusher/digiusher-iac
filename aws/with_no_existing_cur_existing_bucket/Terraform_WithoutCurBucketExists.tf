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

resource "aws_cur_report_definition" "digiusher_cost_and_usage_report" {
  report_name           = "DigiUsherCostAndUsageReport_${var.bucket_name}"
  time_unit             = "DAILY"
  format                = "textORcsv"
  compression           = "ZIP"
  s3_bucket             = var.bucket_name
  s3_region             = "us-east-1"
  s3_prefix             = "CUR/"
  additional_schema_elements = ["RESOURCES"]
  refresh_closed_reports = true
  report_versioning     = "OVERWRITE_REPORT"
}

resource "aws_iam_role" "digiusher_iam_role" {
  name               = var.role_name
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect"    : "Allow",
      "Principal" : { "AWS" : "arn:aws:iam::058264546051:root" },
      "Action"    : "sts:AssumeRole"
    }]
  })

  inline_policy {
    name   = "DigiUsherRolePolicy"
    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [{
        "Sid"     : "DigiUsherRecommendationsPermissions",
        "Effect"  : "Allow",
        "Action"  : [
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
          "tag:GetResources",
          "iam:ListAccessKeys"
        ],
        "Resource" : "*"
      },
      {
        "Sid"     : "DigiUsherCURPermissions",
        "Effect"  : "Allow",
        "Action"  : [
          "s3:ListBucket",
          "s3:GetObject"
        ],
        "Resource" : [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
         ]
       }]
    })
  }
}

output "iam_role_arn" {
  description = "Role ARN Value"
  value       = aws_iam_role.digiusher_iam_role.arn
}

output "report_name" {
  description = "Report Name"
  value       = aws_cur_report_definition.digiusher_cost_and_usage_report.report_name
}
