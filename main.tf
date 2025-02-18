# ============================
#  AWS PROVIDER CONFIGURATION
# ============================
provider "aws" {
  region = "eu-north-1"
}

# ============================
#  NETWORK SETUP - VPC & SUBNETS
# ============================
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = true
}

# ============================
#  EKS CLUSTER SETUP
# ============================
resource "aws_eks_cluster" "eks" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  }
}

resource "aws_iam_role" "eks_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_role.name
}

# ============================
#  WORKER NODE GROUP
# ============================
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "eks-node-group"
  node_role_arn   = aws_iam_role.worker_role.arn
  subnet_ids      = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  scaling_config {
    min_size     = 1
    max_size     = 2
    desired_size = 1
  }
}

resource "aws_iam_role" "worker_role" {
  name = "eks-worker-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Attach all required policies for worker nodes
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker_role.name
}

resource "aws_iam_role_policy_attachment" "worker_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker_role.name
}

resource "aws_iam_role_policy_attachment" "worker_ec2_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.worker_role.name
}

resource "aws_iam_role_policy_attachment" "worker_ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.worker_role.name
}

# ============================
#  KUBERNETES ACCESS CONTROL (RBAC)
# ============================
resource "aws_iam_role" "eks_admin" {
  name = "eks-admin"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_admin_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_admin.name
}

resource "aws_iam_role" "eks_readonly" {
  name = "eks-read-only"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_readonly_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AWSOrganizationsReadOnlyAccess"
  role       = aws_iam_role.eks_readonly.name
}

# ============================
#  KUBERNETES AUTHENTICATION SETUP
# ============================
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks.name
}

# ============================
#  ATLANTIS DEPLOYMENT VIA HELM
# ============================
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks.endpoint
    token                  = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority.0.data)
  }
}

resource "helm_release" "atlantis" {
  name       = "atlantis"
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"

  # Use correct allowlist syntax for GitHub repository
  set {
    name  = "org.allowlist"
    value = "github.com/marks80/exam"
  }

  # Securely provide GitHub authentication via environment variables
  set {
    name  = "github.user"
    value = "$GITHUB_USER"
  }

  set {
    name  = "github.token"
    value = "$GITHUB_TOKEN"
  }
}
