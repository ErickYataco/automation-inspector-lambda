resource "aws_iam_role" "LambdaInspectorRole" {
  name = "LambdaInspectorRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "LambdaInspectorPolicy" {
  name        = "LambdaInspectorPolicy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ],
    "Resource": "arn:aws:logs:*:*:*",
    "Effect": "Allow"
  },
  {
    "Action": [
      "inspector:DescribeFindings"
    ],
    "Resource": "*",
    "Effect": "Allow"
  }]
}
EOF
}

resource "aws_iam_role_policy_attachment" "LambdaInspectorPolicyAttachment" {
  role   = "${aws_iam_role.LambdaInspectorRole.id}"
  policy_arn = "${aws_iam_policy.LambdaInspectorPolicy.arn}"
}

resource "aws_iam_role_policy_attachment" "SSM-role-policy-attach" {
  role       = "${aws_iam_role.LambdaInspectorRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

# resource "aws_iam_role_policy_attachment" "lambda-policy-attach" {
#   role       = "${aws_iam_role.LambdaInspectorRole.name}"
#   policy_arn = "arn:aws:iam::aws:policy/AWSLambdaBasicExecutionRole"
# }

data "null_data_source" "LambdaInspectorFile" {
  inputs = {
    filename = "/lambda/LambdaInspector.js"
  }
}

data "null_data_source" "LambdaInspectorArchive" {
  inputs = {
    filename = "${path.module}/lambda/LambdaInspector.zip"
  }
} 

data "archive_file" "LambdaInspector" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  source_file = "${data.null_data_source.LambdaInspectorFile.outputs.filename}"
  output_path = "${data.null_data_source.LambdaInspectorArchive.outputs.filename}"
}

resource "aws_cloudwatch_log_group" "LambdaInspectorLoggingGroup" {
  name = "/aws/lambda/LambdaInspector"
}

resource "aws_lambda_function" "LambdaInspector" {
  filename         = "${data.archive_file.LambdaInspector.output_path}"
  function_name    = "LambdaInspector"
  role             = "${aws_iam_role.LambdaInspectorRole.arn}"
  handler          = "LambdaInspector.handler"
  source_code_hash = "${data.archive_file.LambdaInspector.output_base64sha256}"
  runtime          = "nodejs10.x"
  timeout          = 60

}

resource "aws_lambda_permission" "allowSNSInspector" {
    statement_id    = "AllowExecutionFromSNSInspector"
    action          = "lambda:InvokeFunction"
    function_name   = "${aws_lambda_function.LambdaInspector.function_name}"
    principal       = "sns.amazonaws.com"
    source_arn      = "${aws_sns_topic.inspector.arn}"
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = "${aws_sns_topic.inspector.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.LambdaInspector.arn}"
}




