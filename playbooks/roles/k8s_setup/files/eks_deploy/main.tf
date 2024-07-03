# Data source for AWS availability zones
data "aws_availability_zones" "available" {}

# Create a new VPC
resource "aws_vpc" "ascender_eks_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ascender-eks-vpc"
  }
}

# Create public subnets
resource "aws_subnet" "ascender_eks_public_subnets" {
  count                   = 2
  vpc_id                  = aws_vpc.ascender_eks_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.ascender_eks_vpc.cidr_block, 8, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
}

# Create an internet gateway
resource "aws_internet_gateway" "ascender_eks_igw" {
  vpc_id = aws_vpc.ascender_eks_vpc.id
  tags = {
    Name = "ascender-eks-igw"
  }
}

# Create route table
resource "aws_route_table" "ascender_eks_route_table" {
  vpc_id = aws_vpc.ascender_eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ascender_eks_igw.id
  }
  tags = {
    Name = "ascender-eks-route-table"
  }
}

# Associate route table with subnets
resource "aws_route_table_association" "eks_route_table_association" {
  count          = 2
  subnet_id      = element(aws_subnet.ascender_eks_public_subnets.*.id, count.index)
  route_table_id = aws_route_table.ascender_eks_route_table.id
}

# IAM role for eks
resource "aws_iam_role" "ascender_eks_cluster_role" {
  name = "ascender-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ascender_eks_cluster_policy" {
  role       = aws_iam_role.ascender_eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Create EKS Cluster
resource "aws_eks_cluster" "ascender_eks_cluster" {
  name     = var.eks_cluster_name
  version  = var.kubernetes_version  # Specify Kubernetes version here
  role_arn = aws_iam_role.ascender_eks_cluster_role.arn

  vpc_config {
    subnet_ids = aws_subnet.ascender_eks_public_subnets.*.id
  }
}

resource "aws_iam_role" "ascender_eks_node_group_role" {
  name = "ascender-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.ascender_eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.ascender_eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ascender_eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ascender_eks_node_group_role.name
}

resource "aws_eks_node_group" "ascender_nodes" {
  cluster_name    = aws_eks_cluster.ascender_eks_cluster.name
  node_group_name = "ascender-nodes"
  node_role_arn   = aws_iam_role.ascender_eks_node_group_role.arn
  subnet_ids      = aws_subnet.ascender_eks_public_subnets.*.id

  scaling_config {
    desired_size = var.num_nodes
    max_size     = var.num_nodes
    min_size     = var.num_nodes
  }

  instance_types = [var.aws_vm_size]
  disk_size     = var.volume_size
}
