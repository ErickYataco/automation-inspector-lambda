resource "aws_inspector_resource_group" "GroupInspect" {
  tags = {
    Env = "${aws_instance.inspector-instance.tags.Env}"
  }

  depends_on = [
      "aws_instance.inspector-instance"
  ]
}

resource "aws_inspector_assessment_target" "TargetInspect" {
  name = "inspector-instance-assessment"
  resource_group_arn = "${aws_inspector_resource_group.GroupInspect.arn}"
}

resource "aws_inspector_assessment_template" "TemplateInspect" {
  name       = "Inspect template"
  target_arn = "${aws_inspector_assessment_target.TargetInspect.arn}"
  duration   = 900

  rules_package_arns = [
    "arn:aws:inspector:us-east-1:316112463485:rulespackage/0-gEjTy7T7",
    "arn:aws:inspector:us-east-1:316112463485:rulespackage/0-rExsr2X8",
    "arn:aws:inspector:us-east-1:316112463485:rulespackage/0-R01qwB5Q",
    "arn:aws:inspector:us-east-1:316112463485:rulespackage/0-gBONHN9h",
  ]
}

# https://github.com/terraform-providers/terraform-provider-aws/pull/3957
resource "null_resource" "inspector_sns" {

  provisioner "local-exec" {
    command = "aws --region ${var.region} --profile ${var.aws_profile} inspector subscribe-to-event --resource-arn ${aws_inspector_assessment_template.TemplateInspect.arn} --event FINDING_REPORTED --topic-arn ${aws_sns_topic.inspector.arn}"
  }

  depends_on = [
    "aws_lambda_function.LambdaInspector",
    "aws_sns_topic.inspector"
  ]
}