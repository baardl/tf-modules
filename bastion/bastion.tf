# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "environment" {
  description = "Environment tag which is applied to resources."
  default     = ""
}

variable "authorized_keys" {
  description = "List of public keys which are added to bastion."
  type        = "list"
}

variable "authorized_cidr" {
  description = "List of CIDR blocks which can reach bastion on port 22."
  type        = "list"
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets where bastion can be provisioned."
  type        = "list"
}

variable "pem_bucket" {
  description = "S3 bucket where the PEM key is stored."
}

variable "pem_path" {
  description = "Path (bucket-key) where the PEM key is stored."
}

variable "instance_ami" {
  description = "ID of an Amazon Linux AMI."
  default     = "ami-d7b9a2b1"
}

variable "instance_type" {
  description = "Type of instance to provision."
  default     = "t2.micro"
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

resource "aws_eip" "main" {}

data "template_file" "main" {
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    authorized_keys = "${join("\n  - ", "${var.authorized_keys}")}"
    aws_region      = "${data.aws_region.current.name}"
    elastic_ip      = "${aws_eip.main.public_ip}"
    pem_bucket      = "${var.pem_bucket}"
    pem_path        = "${var.pem_path}"
  }
}

data "aws_iam_policy_document" "permissions" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:AssociateAddress",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = ["arn:aws:s3:::${var.pem_bucket}/${var.pem_path}"]
  }
}

module "asg" {
  source          = "../ec2/asg"
  prefix          = "${var.prefix}-bastion"
  environment     = "${var.environment}"
  user_data       = "${data.template_file.main.rendered}"
  vpc_id          = "${var.vpc_id}"
  subnet_ids      = "${var.subnet_ids}"
  instance_policy = "${data.aws_iam_policy_document.permissions.json}"
  instance_count  = "1"
  instance_type   = "${var.instance_type}"
  instance_ami    = "${var.instance_ami}"
  instance_key    = ""
}

resource "aws_security_group_rule" "ingress" {
  security_group_id = "${module.asg.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["${var.authorized_cidr}"]
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "role_arn" {
  value = "${module.asg.role_arn}"
}

output "security_group_id" {
  value = "${module.asg.security_group_id}"
}

output "ip" {
  value = "${aws_eip.main.public_ip}"
}
