# AWS CloudFormation Stack Creation

This README provides instructions on how to create a CloudFormation stack using the provided templates and how to upload and execute these scripts in your AWS environment.

This repository contains two CloudFormation templates: `CloudFormationWithCur` and `CloudFormationWithoutCur`. The purpose of these templates is to provision AWS resources automatically based on specific requirements.

These templates are designed to cater to different scenarios: one with CUR enabled and one without CUR enabled. By using these templates, you can ensure that the required infrastructure is provisioned correctly based on your specific needs.

## Instructions

1. **Download the Templates**:
   Clone this repository or download the CloudFormation templates `CloudFormationWithCur.yaml` and `CloudFormationWithoutCur.yaml`.

2. **Choose Template**:
   Depending on whether you have Cost and Usage Reports (CUR) enabled or not in your AWS account, choose the appropriate CloudFormation template:
   - If CUR is enabled, use `CloudFormationWithCur.yaml`.
   - If CUR is not enabled, use `CloudFormationWithoutCur.yaml`.

3. **Create CloudFormation Stack**:
   Use the AWS Management Console or AWS CLI to create a CloudFormation stack:

   - **Using AWS Management Console**:
     - Go to the CloudFormation service in the AWS Management Console.
     - Click on "Create stack" and choose "With new resources (standard)".
     - Select "Upload a template file" and upload the chosen template.
     - Follow the on-screen instructions to specify stack details, skip configuring stack options, and create the stack.

   - **Using AWS CLI**:
     Follow these commands to create the stack:
     - For CloudFormationWithoutCur:
       ```
       aws cloudformation create-stack \
           --stack-name YourStackName \
           --template-body file://path/to/CloudFormationWithoutCur.yaml \
           --parameters ParameterKey=RoleName,ParameterValue=YourRoleName \
                        ParameterKey=BucketName,ParameterValue=YourBucketName \
                        ParameterKey=ThirdPartyAccountId,ParameterValue=DigiusherAccountId
       ```

     - For CloudFormationWithCur:
       ```
       aws cloudformation create-stack \
           --stack-name YourStackName \
           --template-body file://path/to/CloudFormationWithCur.yaml \
           --parameters ParameterKey=RoleName,ParameterValue=YourRoleName \
                        ParameterKey=ThirdPartyAccountId,ParameterValue=DigiusherAccountId
       ```

     Replace `YourStackName`, `YourRoleName` and  `YourBucketName` with your desired values. 
     Replace `DigiusherAccountId` with the Account Id shared. 

4. **Monitor Stack Creation**:
   Monitor the stack creation process through the AWS Management Console or AWS CLI:
   - Using AWS Management Console:
     Navigate to the CloudFormation service and monitor the stack status.
   - Using AWS CLI:
     ```
     aws cloudformation describe-stacks --stack-name YOUR_STACK_NAME
     ```
     Look for the "StackStatus" field in the output. If the stack has been created successfully, the status will be CREATE_COMPLETE. If it's still being created, the status will be CREATE_IN_PROGRESS. If there was an error during creation, the status will indicate that (CREATE_FAILED). If the stack is not yet created, you won't receive any output.

5. **Navigate to Outputs**:
   After the stack creation is complete, 
   - Using AWS Management Console:
     Navigate to the "Outputs" section in the CloudFormation stack details.
   - Using AWS CLI:
     ```
     aws cloudformation describe-stacks --stack-name YourStackName --query 'Stacks[].Outputs'
     ```
   
6. **Fill in Output Values**:
   Use the output values provided and fill them in the fields when connecting to the AWS ARN data source.

7. **Policy Attachment Requirement for AWS CLI Users**:
   If you choose to create the stack through the AWS CLI, make sure to attach the following policy to your IAM user:
   ```
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                   "cloudformation:*",
                   "s3:CreateBucket",
                   "s3:PutBucketPolicy",
                   "s3:PutObject",
                   "iam:CreateRole",
                   "iam:PutRolePolicy",
                   "iam:GetRole",
                   "cur:PutReportDefinition"
               ],
               "Resource": "*"
           }
       ]
   }