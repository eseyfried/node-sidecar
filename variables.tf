
variable "ecs_cluster" {
  description = "ECS cluster name"
  default = "microservice_a"
}



########################### Test VPC Config ################################





########################### Autoscale Config ################################

variable "max_instance_size" {
  description = "Maximum number of instances in the cluster"
  default = 1
}

variable "min_instance_size" {
  description = "Minimum number of instances in the cluster"
  default = 1
}

variable "desired_capacity" {
  description = "Desired number of instances in the cluster"
  default = 1
}