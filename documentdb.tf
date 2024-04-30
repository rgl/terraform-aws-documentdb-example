locals {
  example_docdb_port = 27017
  # see Connecting Programmatically to Amazon DocumentDB at https://docs.aws.amazon.com/documentdb/latest/developerguide/connect_programmatically.html#connect_programmatically-tls_enabled
  example_docdb_master_connection_string = format(
    "mongodb://%s:%s@%s:%d/?tls=true&tlsCAFile=global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false",
    urlencode(aws_docdb_cluster.example.master_username),
    urlencode(aws_docdb_cluster.example.master_password),
    aws_docdb_cluster.example.endpoint,
    aws_docdb_cluster.example.port
  )
}

# see https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password
resource "random_password" "example_docdb_master_password" {
  length           = 16 # min 8.
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%&*()-_=+[]{}<>:?" # NB cannot contain /"@
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_cluster
resource "aws_docdb_cluster" "example" {
  cluster_identifier           = var.name_prefix
  availability_zones           = module.vpc.azs
  db_subnet_group_name         = module.vpc.database_subnet_group
  vpc_security_group_ids       = [aws_security_group.example_docdb.id]
  port                         = local.example_docdb_port
  engine                       = "docdb"
  engine_version               = "5.0.0"
  master_username              = "master"
  master_password              = random_password.example_docdb_master_password.result
  preferred_maintenance_window = "mon:00:00-mon:03:00"
  preferred_backup_window      = "04:00-06:00"
  backup_retention_period      = 1 # [days]. min 1.
  skip_final_snapshot          = true
  apply_immediately            = true
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_cluster_instance
resource "aws_docdb_cluster_instance" "example" {
  count                        = 1
  identifier                   = "example${count.index}"
  cluster_identifier           = aws_docdb_cluster.example.id
  instance_class               = "db.t3.medium"
  preferred_maintenance_window = "tue:00:00-tue:03:00"
  apply_immediately            = true
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "example_docdb" {
  vpc_id      = module.vpc.vpc_id
  name        = "example-docdb"
  description = "Example DocumentDB Database"
  tags = {
    Name = "${var.name_prefix}-docdb"
  }
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule
resource "aws_vpc_security_group_ingress_rule" "example_docdb_mongo" {
  for_each = {
    for i, cidr_block in module.vpc.intra_subnets_cidr_blocks : i => {
      az        = module.vpc.azs[i]
      cidr_ipv4 = cidr_block
    }
  }

  security_group_id = aws_security_group.example_docdb.id
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value.cidr_ipv4
  from_port         = local.example_docdb_port
  to_port           = local.example_docdb_port
  tags = {
    Name = "${var.name_prefix}-docdb-mongo-${each.value.az}"
  }
}
