provider "aws" {
  region = "ap-northeast-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

locals {
  vpc_name = "default"
  common_tags = {
    "Project" = "provisioner-userdata"
  }
}
resource "aws_default_vpc" "default" {
  tags = {
    Name = local.vpc_name
  }
}

module "security_group" {
  source  = "tedilabs/network/aws//modules/security-group"
  version = "0.24.0"

  name        = "${local.vpc_name}-provisioner-userdata"
  description = "Security Group for test."
  vpc_id      = aws_default_vpc.default.id

  ingress_rules = [
    {
      id          = "ssh"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow SSH from anywhere."
    },
    {
      id          = "http"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP from anywhere."
    },
  ]
  egress_rules = [
    {
      id          = "all/all"
      description = "Allow to communicate to the Internet."
      protocol    = "-1"
      from_port   = 0
      to_port     = 0

      cidr_blocks = ["0.0.0.0/0"]
    },
  ]

  tags = local.common_tags
}


###################################################
# Userdata
###################################################

# user data 같은 경우는 ec2에서 제공해주는 기능이기 때문에
# terraforma에 script 실행에 대한 로그가 남지 않는다.
resource "aws_instance" "userdata" {
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = "t2.micro"
  key_name      = "insomenia-public-keypair"

# user data script는 ec2 instance가 첫 부팅될 때만 사용할 수 있다.
# 만약 파일을 수정하고 `tf apply`를 하면 terraform이 instance를 삭제하고 다시 설치하냐고 물어본다.
  user_data = <<EOT
#!/bin/bash
sudo apt-get update
sudo apt-get install -y nginx
EOT

  vpc_security_group_ids = [
    module.security_group.id,
  ]

  tags = {
    Name = "fastcampus-userdata"
  }
}


###################################################
# Provisioner - in EC2
###################################################

# provisioner 같은 경우 terraform에서 제공해주는 기능이기 때문에
# ec2에 connection을 맺는 것부터 script가 실행되는 로그가 전부 남는다.
# resource "aws_instance" "provisioner" {
#   ami           = data.aws_ami.ubuntu.image_id
#   instance_type = "t2.micro"
#   key_name      = "insomenia-public-keypair"

#   vpc_security_group_ids = [
#     module.security_group.id,
#   ]

#   tags = {
#     Name = "fastcampus-provisioner"
#   }

#   # provisioner는 기본적으로 creation-time provisioner다.
#   # 즉 instance가 생성될 때마다 실행된다. sciprt를 추가해도 userdata와 달리 아무런 변화가 없다.
#   provisioner "remote-exec" {
#     inline = [
#       "sudo apt-get update",
#       "sudo apt-get install -y nginx",
#     ]
#     # inline말고도 script, scripts를 사용할 수 있는데
#     # script는 로컬에 있는 script 파일을 올린다.

#     connection {
#       type = "ssh"
#       user = "ubuntu"
#       host = self.public_ip
#       # self는 provisioner에서만 사용할 수 있는 변수다.
#     }
#     # ssh-agent를 사용하던가 password나 private_key를 사용해야 한다.
#     # 현업에서는 ssh-agent를 사용해야 코드 상에 비밀 데이터가 남지 않아서 보안상 좋다.
#   }
# }


###################################################
# Provisioner - in null-resources
###################################################

resource "aws_instance" "provisioner" {
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = "t2.micro"
  key_name      = "insomenia-public-keypair"

  vpc_security_group_ids = [
    module.security_group.id,
  ]

  tags = {
    Name = "fastcampus-provisioner"
  }
}

resource "null_resource" "provisioner" {
  triggers = {
    insteance_id = aws_instance.provisioner.id
    script       = filemd5("${path.module}/files/install-nginx.sh")
    index_file   = filemd5("${path.module}/files/index.html")
  }

  provisioner "local-exec" {
    command = "echo Hello World"
  }

  provisioner "file" {
    source      = "${path.module}/files/index.html"
    destination = "/tmp/index.html"

    connection {
      type = "ssh"
      user = "ubuntu"
      host = aws_instance.provisioner.public_ip
    }
  }

  provisioner "remote-exec" {
    script = "${path.module}/files/install-nginx.sh"

    connection {
      type = "ssh"
      user = "ubuntu"
      host = aws_instance.provisioner.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cp /tmp/index.html /var/www/html/index.html"
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
      host = aws_instance.provisioner.public_ip
    }
  }
}
