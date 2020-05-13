resource "aws_iam_role" "CloudWatchAgentAdminRole" {
  name = "CloudWatchAgentAdminRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  
}

resource "aws_iam_role_policy_attachment" "ec2-SSM-role-policy-attach" {
  role       = "${aws_iam_role.CloudWatchAgentAdminRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "inspector-role-policy-attach" {
  role       = "${aws_iam_role.CloudWatchAgentAdminRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonInspectorFullAccess"
}

resource "aws_iam_role_policy_attachment" "SSM-fullAccess-role-policy-attach" {
  role       = "${aws_iam_role.CloudWatchAgentAdminRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_role_policy_attachment" "cloudWatch-role-policy-attach" {
  role       = "${aws_iam_role.CloudWatchAgentAdminRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentAdminPolicy"
}

resource "aws_iam_instance_profile" "inspector_profile" {
  name = "ec2-instance-profile"
  role = "${aws_iam_role.CloudWatchAgentAdminRole.name}"
}
resource "aws_key_pair" "inspectkey" {
  public_key = "${file(var.path_to_pub_key)}"
}

resource "aws_security_group" "AllowSSH" {
  name        = "AllowSSH"
  description = "security group for prometheus instance"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "init" {
    template = "${file("install_inspector.sh")}"
}

resource "aws_instance" "inspector-instance" {
  ami                       = "ami-13be557e"  
  instance_type             = "t2.micro"
  iam_instance_profile      = "${aws_iam_instance_profile.inspector_profile.id}"
  key_name                  = "${aws_key_pair.inspectkey.key_name}"
  vpc_security_group_ids    =["${aws_security_group.AllowSSH.id}"]
  user_data                 = "${data.template_file.init.rendered}"


  tags = {
    Name = "InspectInstances"
    Env  = "Dev"
  }
}