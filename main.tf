# Stand vor dem web-Module, in das Web-Module sollten die Resourcen:
# * aws_instance.web_server
# * aws_security_group.web_server
# * aws_eip.ip
# Nach der Umorganisation sollen sowohl die Resourcen als auch die Outputs gleich funktionieren wie vorher.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.37"
    }
  }
}



provider "aws" {
  region = "eu-central-1"
  profile = "tomislav"
}


data "aws_caller_identity" "current" {}

data "aws_ami" "base" {
  owners           = [data.aws_caller_identity.current.account_id]
  most_recent      = true

  filter {
    name   = "name"
    values = ["my_base_image*"]
  }
}


resource "random_string" "server" {
  length  = 8
  special = false
  number  = false
  upper   = false
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id = random_string.server.result
  node_type  = "cache.t2.micro"

  engine               = "redis"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis5.0"
  engine_version       = "5.0.4"
  security_group_ids   = [aws_security_group.redis.id]
}

resource "aws_security_group" "redis" {
  ingress {
    protocol                 = "tcp"
    from_port                = 6379
    to_port                  = 6379
    security_groups = [module.webserver.aws_webserver_id]
  }
}


module "webserver" {
   source="./module/webserver"
   redis_address = aws_elasticache_cluster.redis.cache_nodes[0].address
   aws_ami_id = data.aws_ami.base.id
}


output "ip" {
  value = module.webserver.aws_eip
}
