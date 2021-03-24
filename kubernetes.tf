/**
 * Copyright 2021 Taito United
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  worker_groups = [
    for pool in local.kubernetes.nodePools:
    {
      name                 = "default_worker_group"
      instance_type        = pool.machineType
      subnets              = var.private_subnets
      asg_desired_capacity = pool.minNodeCount
      asg_min_size         = pool.minNodeCount
      asg_max_size         = pool.maxNodeCount
    }
  ]
}

resource "aws_iam_policy" "node" {
  name = "${local.kubernetes}-node"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_security_group" "kubernetes_node" {
  name_prefix = "kubernetes_node"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
    /*
      "172.16.0.0/12",
      "192.168.0.0/16",
    */
  }

  tags = local.tags
}

module "kubernetes" {
  count                                = local.kubernetes != "" ? 1 : 0

  source                               = "terraform-aws-modules/eks/aws"
  version                              = "14.0.0"
  cluster_name                         = local.kubernetes.name
  cluster_version                      = local.kubernetes.version
  subnets                              = var.private_subnets
  tags                                 = local.tags
  vpc_id                               = var.vpc_id
  worker_groups                        = local.worker_groups
  worker_additional_security_group_ids = [aws_security_group.kubernetes_node.id]
  # workers_group_defaults               = local.workers_group_defaults

  map_accounts = var.additional_accounts

  /* TODO: not required? -> use permissions?
  map_roles    = var.roles
  map_users    = var.users
  */

  workers_additional_policies = [
    aws_iam_policy.node.arn
  ]

  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  write_kubeconfig      = false
  # write_aws_auth_config = false

  kubeconfig_aws_authenticator_env_variables = {
    AWS_PROFILE = var.user_profile
  }
}
