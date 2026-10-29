resource "aws_security_group" "mon" {
  name        = "sre-lab-mon"
  description = "Monitoring: SSH, Prometheus i Grafana tylko z mojego IP"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH z mojego IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Prometheus z mojego IP"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Grafana z mojego IP"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sre-lab-mon"
  }
}

resource "aws_instance" "mon" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.mon.id]
  key_name               = aws_key_pair.lab.key_name

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
  }

  tags = {
    Name = "sre-lab-mon"
  }
}

output "mon_public_ip" {
  value = aws_instance.mon.public_ip
}

output "web_private_ips" {
  value = { for name, inst in aws_instance.web : name => inst.private_ip }
}
