data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

}

# IAM role for GitHub Actions to push Docker images to ECR
resource "aws_iam_role" "github_actions" {
  name = "github-actions-ecr-push-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:GeorgeEliWilliams/self-healing-aws-infra:*"
          }
        }
      }
    ]
  })
}

# IAM policy for the GitHub Actions role to push Docker images to ECR
resource "aws_iam_role_policy" "github_actions_ecr_push" {
  name = "github-actions-ecr-push-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = aws_ecr_repository.healthcheck_app.arn
      }
    ]
  })
}

# IAM policy for the GitHub Actions role to send SSM commands to the EC2 instance
resource "aws_iam_role_policy" "github_actions_ssm_deploy" {
  name = "github-actions-ssm-deploy-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "ssm:SendCommand"
        Resource = [
          "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.k3s_node.id}",
          "arn:aws:ssm:eu-west-1::document/AWS-RunShellScript"
        ]
      }
    ]
  })
}