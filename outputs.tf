

output "alb_dns_name" {
    value = aws_alb.ecs-load-balancer.dns_name
}