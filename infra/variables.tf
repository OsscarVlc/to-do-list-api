variable "region" {
  description = "Región de AWS donde se crean los recursos"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo para nombrar los recursos"
  type        = string
  default     = "todo-api"
}

variable "instance_type" {
  description = "Tamaño de la instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "allowed_cidr" {
  description = "Rango de IPs que puede entrar por SSH y a la API"
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_port" {
  description = "Puerto donde escucha la API"
  type        = number
  default     = 3000
}

variable "repo_url" {
  description = "Repositorio público que la EC2 clona al arrancar"
  type        = string
  default     = "https://github.com/OsscarVlc/to-do-list-api.git"
}