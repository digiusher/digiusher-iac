# DigiUsher CloudFormation Stack Creation - AWS

This directory contains tempaltes for multiple scenarios:

- [Linked accounts](./linked_accounts) - For linked accounts which do not need their own CUR data. The CUR data is picked from the root account (the root account should be connected first with one of the other following scenarios).
- [Create new CUR and new bucket (recommended for root accounts)](./with_no_existing_cur_new_bucket) - Create a new bucket and configure a new CUR to send data to the bucket.
- [Create new CUR in an existing bucket](./with_no_existing_cur_new_bucket) - When you want to create a new CUR in an existing bucket
- [With Existing CUR](./with_existing_cur) - When you have an existing CUR that you want to reuse for DigiUsher


This instructions README is split up into two parts:

 - [Cloudformation](./README.cf.md)
 - [Terraform](./README.tf.md)
