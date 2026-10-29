data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "lab" {
  key_name   = "sre-lab"
  public_key = file("~/.ssh/lab_vm.pub")
}

locals {
  web_servers = {
    web1 = aws_subnet.public_a.id
    web2 = aws_subnet.public_b.id
  }
}

resource "aws_instance" "web" {
  for_each = local.web_servers

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = each.value
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.lab.key_name

  user_data_replace_on_change = true
  user_data                   = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "Hello from ${each.key}" > /var/www/html/index.html
  EOF

  tags = {
    Name = "sre-lab-${each.key}"
  }
}

resource "aws_lb" "web" {
  name               = "sre-lab-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "web" {
  name     = "sre-lab-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.lab.id

  health_check {
    path    = "/"
    matcher = "200"
  }
}

resource "aws_lb_target_group_attachment" "web" {
  for_each = aws_instance.web

  target_group_arn = aws_lb_target_group.web.arn
  target_id        = each.value.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

output "alb_dns" {
  value = aws_lb.web.dns_name
}

output "web_public_ips" {
  value = { for name, inst in aws_instance.web : name => inst.public_ip }
}
