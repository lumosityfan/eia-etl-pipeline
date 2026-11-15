resource "aws_sns_topic" "pipeline_notifications" {
    name = "eia-etl-pipeline-notifications"
}

resource "aws_sns_topic_subscription" "email" {
    topic_arn = aws_sns_topic.pipeline_notifications.arn
    protocol = "email"
    endpoint = var.notification_email
}