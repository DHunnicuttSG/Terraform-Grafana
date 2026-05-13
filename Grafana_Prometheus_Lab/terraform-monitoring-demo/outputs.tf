output "instance_public_ip" {
  value = aws_instance.demo.public_ip
}

output "grafana_url" {
  value = "http://${aws_instance.demo.public_ip}:3000"
}

output "prometheus_url" {
  value = "http://${aws_instance.demo.public_ip}:9090"
}