provider "aws" {
  region = "us-east-1"

}

resource "aws_vpc" "pvpc" {

  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "ELB VPC"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.pvpc.id
  tags = {
    Name = "Internet gateway for Terraform"
  }
}

resource "aws_subnet" "pubsubnet1" {
  vpc_id            = aws_vpc.pvpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "public elb subnet 1a"
  }

}

resource "aws_subnet" "pubsubnet2" {
  vpc_id            = aws_vpc.pvpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "public elb subnet 1b"
  }
}

resource "aws_security_group" "sgforalb" {

  description = "security group for the application load balancer in aws"
  vpc_id      = aws_vpc.pvpc.id
}
resource "aws_vpc_security_group_ingress_rule" "albingressrule" {

  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.sgforalb.id

  tags = {
    Name = "ALB ingress rule"
  }
}

resource "aws_lb" "alb" {

  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sgforalb.id]
  subnets            = [aws_subnet.pubsubnet1.id, aws_subnet.pubsubnet2.id]
  tags = {
    Name = "Terraform Application Load Balancer"
  }
}

resource "aws_lb_target_group" "albtargetgroup" {

  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.pvpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 4
    unhealthy_threshold = 2


  }
  tags = {
    Name = "ALB Target Group"
  }

}

resource "aws_lb_listener" "alblistener" {

  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {

    type             = "forward"
    target_group_arn = aws_lb_target_group.albtargetgroup.arn
  }
  tags = {
    Name = "ALB Listener"
  }
}

resource "aws_subnet" "prisubnet1" {
  vpc_id     = aws_vpc.pvpc.id
  cidr_block = "10.0.3.0/24"
  tags = {
    Name = "Private Subnet"
  }
}

resource "aws_security_group" "sgforprivateinstance" {

  vpc_id = aws_vpc.pvpc.id
}

resource "aws_vpc_security_group_ingress_rule" "instanceingressrule" {

  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.sgforprivateinstance.id
  referenced_security_group_id = aws_security_group.sgforalb.id

  tags = {
    Name = "Security Group for the Private Instances"
  }

}

/*
resource "aws_security_group_rule" "flow_alb_to_instance" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = 80
  security_group_id        = aws_security_group.sgforprivateinstance.id
  source_security_group_id = aws_security_group.sgforalb.id

}
*/

resource "aws_instance" "awsinstance" {
  for_each      = toset(["instance1", "instance2", "instance3"])
  ami           = "ami-012967cc5a8c9f891"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.prisubnet1.id

  security_groups = [aws_security_group.sgforprivateinstance.id]

  user_data = <<-EOF
	sudo apt update -y
	sudo apt install httpd -y
	systemctl start httpd
	systemctl enable httpd
	echo "Hello from Terraform" > /var/www/html/index.html
	EOF

  tags = {
    Name = "${each.key}"
  }
}

resource "aws_lb_target_group_attachment" "target-instance-attachment" {
  for_each         = aws_instance.awsinstance
  target_group_arn = aws_lb_target_group.albtargetgroup.arn
  target_id        = each.value.id
  port             = 80
}











