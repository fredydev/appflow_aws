terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.16.0"
    }
  }
}


data "aws_caller_identity" "current" {}

resource "aws_appflow_flow" "salesforce_to_eventbridge" {
  name = "example"

  source_flow_config {
    connector_type = "Salesforce"
    connector_profile_name = "test-connect"
    source_connector_properties {
      salesforce {
        object = "AccountChangeEvent"
      }
    }
  }

  destination_flow_config {
    connector_type = "EventBridge"
    destination_connector_properties {
      event_bridge {
        object = "aws.partner/appflow/salesforce.com/${data.aws_caller_identity.current.account_id}/example"

        error_handling_config {
          bucket_name = module.large_events_bucket.s3_bucket_id
        }
      }
    }
  }

  task {
    task_type         = "Map_all"
    source_fields     = [""]
    task_properties = {
      EXCLUDE_SOURCE_FIELDS_LIST = "[]"
    }
    connector_operator {
      salesforce = "NO_OP"
    }
  }

  trigger_config {
    trigger_type = "Event"
  }
}

locals {
  large_events_bucket_name = "asdfasdf-appflow-salesforce-large-events"
}

module "large_events_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.2.1"

  bucket = local.large_events_bucket_name
  acl    = "private"

  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "appflow.amazonaws.com"
      }
      Action = [
        "s3:PutObject",
        "s3:GetBucketAcl",
        "s3:PutObjectAcl",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts",
        "s3:ListBucketMultipartUploads",
      ]
      Resource = [
        "arn:aws:s3:::${local.large_events_bucket_name}",
        "arn:aws:s3:::${local.large_events_bucket_name}/*",
      ]
    }]
  })
}