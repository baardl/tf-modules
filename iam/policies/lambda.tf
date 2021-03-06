# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "lambda" {
  count  = "${contains(var.services, "lambda") == "true" ? 1 : 0}"
  name   = "${var.prefix}-lambda-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.lambda.json}"
}

data "aws_iam_policy_document" "lambda" {
  statement {
    effect = "Allow"

    actions = [
      "lambda:*",
    ]

    resources = [
      "arn:aws:lambda:${var.region}:${var.account_id}:function:${coalesce(var.resources, "${var.prefix}-*")}",
    ]
  }
}
