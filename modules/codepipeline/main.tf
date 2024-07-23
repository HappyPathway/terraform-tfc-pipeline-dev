#This solution, non-production-ready template describes AWS Codepipeline based CICD Pipeline for terraform code deployment.
#© 2023 Amazon Web Services, Inc. or its affiliates. All Rights Reserved.
#This AWS Content is provided subject to the terms of the AWS Customer Agreement available at
#http://aws.amazon.com/agreement or other written agreement between Customer and either
#Amazon Web Services, Inc. or Amazon Web Services EMEA SARL or both.
resource "aws_codestarconnections_connection" "repo_connection" {
  count         = var.repo_connection != null ? 1 : 0
  name          = var.repo_connection.name
  provider_type = var.repo_connection.provider_type
}

resource "aws_codepipeline" "terraform_pipeline" {

  name     = "${var.project_name}-pipeline"
  role_arn = var.codepipeline_role_arn
  tags     = var.tags

  artifact_store {
    location = var.s3_bucket_name
    type     = "S3"
    encryption_key {
      id   = var.kms_key_arn
      type = "KMS"
    }
  }

  dynamic "stage" {
    for_each = toset(var.source_repos)
    content {
      name = "Source"

      action {
        name             = stage.value.name
        category         = "Source"
        owner            = "AWS"
        version          = "1"
        provider         = stage.value.provider_type
        namespace        = "SourceVariables"
        output_artifacts = [stage.value.name]
        run_order        = 1

        configuration = stage.value.provider_type == "CodeCommit" ? {
          RepositoryName       = stage.value.name
          BranchName           = stage.value.branch
          PollForSourceChanges = stage.value.poll_for_source_changes
          } : stage.value.provider_type == "CodeStarSourceConnection" ? {
          ConnectionArn    = aws_codestarconnections_connection.repo_connection[0].arn
          FullRepositoryId = stage.value.name
          BranchName       = stage.value.branch
        } : null
      }
    }
  }

  dynamic "stage" {
    for_each = var.stages
    content {
      name = stage.value["name"]
      action {
        category         = stage.value["category"]
        name             = "Action-${stage.value["name"]}"
        owner            = stage.value["owner"]
        provider         = stage.value["provider"]
        input_artifacts  = lookup(stage.value, "input_artifacts", "") != "" ? [stage.value["input_artifacts"]] : null
        output_artifacts = lookup(stage.value, "output_artifacts", "") != "" ? [stage.value["output_artifacts"]] : null
        version          = "1"
        run_order        = index(var.stages, stage.value) + 2

        configuration = {
          ProjectName = stage.value["provider"] == "CodeBuild" ? "${var.project_name}-${stage.value["name"]}" : null
        }
      }
    }
  }

}