variable "service_name" {
  description = "The name of the service that will be deployed"
  default = "envoy-ssl-tutorial"
}

variable "subnet_id" {
  description = "The id of the subnet where the service will run"
}

variable "vpc_id" {
  description = "The id of the VPC where the service will run"
}

variable "task_role" {
  description = "The ARN of the task execution role"
}
