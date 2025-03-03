build {
  name = "fastcampus-packer"

  source "amazon-ebs.ubuntu" {
    name     = "nginx"
    ami_name = "fastcampus-packer-nginx"
  }

  # provisioner는 정의한 순서가 중요!!

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "whoami",
    ]
  }

  provisioner "file" {
    source      = "${path.root}/files/index.html"
    destination = "/tmp/index.html"
  }

  provisioner "shell" {
    inline = [
      # source.name = nginx / source.type = amazon-ebs
      "echo ${source.name} and ${source.type}",
      # "whoami",
      "sudo apt-get install -y nginx",
      "sudo cp /tmp/index.html /var/www/html/index.html"
    ]
  }

  provisioner "breakpoint" {
    disable = false
    note    = "디버깅용"
  }
}
