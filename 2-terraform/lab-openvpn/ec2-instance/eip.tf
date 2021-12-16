resource "aws_eip" "openvpn" {
  tags = merge(
    {
      "Name" = "${local.vpc.name}-openvpn"
    },
    local.common_tags,
  )
}

resource "aws_eip_association" "openvpn" {
  # ec2 machine이 종료되었다가 다시 생성되면 public ip는 갱신된다.
  # eip는 지우지 않는 이상 유지가 가능
  # 실습에서 굳이 사용할 필요는 없지만 현업에서 중요한 서버는 eip를 사용해야 한다.
  instance_id   = aws_instance.openvpn.id
  allocation_id = aws_eip.openvpn.id
}
