# Creates an S3 bucket that sends object created events to EventBridge,
# which are then written to a CloudWatch log group.
# See: https://repost.aws/knowledge-center/cloudwatch-log-group-eventbridge

provider "aws" {}

# S3 bucket for sending events to EventBridge
resource "aws_s3_bucket" "this" {
  bucket = "terraform-aws-recipes"
}

# Enable sending events to EventBridge
resource "aws_s3_bucket_notification" "this" {
  bucket      = aws_s3_bucket.this.bucket
  eventbridge = true
}

# Rule to capture object created events on the default event bus
resource "aws_cloudwatch_event_rule" "this" {
  event_pattern = jsonencode({
    source      = ["aws.s3"],
    detail-type = ["Object Created"],
    detail = {
      bucket = {
        name = [aws_s3_bucket.this.bucket]
      }
    }
  })
}

# Create a CloudWatch log group to use as the event target
# Note: Needs to start with /aws/events
resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/events/object-created-events"
}

# Set the log group as the event target
resource "aws_cloudwatch_event_target" "this" {
  rule = aws_cloudwatch_event_rule.this.name
  arn  = aws_cloudwatch_log_group.this.arn
}

# Resource-based policy that allows EventBridge to write to the log group
data "aws_iam_policy_document" "this" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "delivery.logs.amazonaws.com",
      ]
    }
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

# Enable the resource-based policy
resource "aws_cloudwatch_log_resource_policy" "this" {
  policy_document = data.aws_iam_policy_document.this.json
  policy_name     = "eventbridge-policy"
}
