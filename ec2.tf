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
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2RoleForSSM"
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
# resource "aws_key_pair" "inspectkey" {
#   public_key = "${file(var.PATH_TO_PUB_KEY)}"
# }

resource "aws_instance" "inspector-instance" {
  ami = "ami-d80c35bd" #"amzn2-ami-hvm-2.0.20180622.1-x86_64-ebs()"
  instance_type = "t2.micro"
  iam_instance_profile  = "${aws_iam_instance_profile.inspector_profile.id}"
  #key_name = "${aws_key_pair.inspectkey.key_name}"
  security_groups = ["inspect"]

  tags = {
    Name = "InspectInstances"
    Env  = "Dev"
  }

  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ubuntu"
      #private_key = "${file("${var.PATH_TO_PRIVATE_KEY}")}"
      host = "${aws_instance.inspector-instance.public_ip}"
    }
    inline = [
      "wget https://d1wk0tztpsntt1.cloudfront.net/linux/latest/install -P /tmp/",
      "sudo bash /tmp/install"
    ]
  }
}