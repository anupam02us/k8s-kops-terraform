resource "aws_iam_user" "kops" {
  name = "kops2"
  path = "/"
}

resource "aws_iam_user_policy" "kops_access" {
  name = "kops_access"
  user = aws_iam_user.kops.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:*",
          "route53:*",
          "s3:*",
          "iam:*",
          "vpc:*",
          "sqs:*",
          "events:*",
          "autoscaling:*",
          "elasticloadbalancing:*",
          "s3:PutBucketAcl",
          "s3:GetBucketAcl"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "kops" {
  user = aws_iam_user.kops.id
}

resource "aws_route53_zone" "domain" {
  name          = var.kops_domain
  force_destroy = true
}

resource "aws_route53_zone" "sub_domain" {
  name          = var.kops_sub_domain
  force_destroy = true
}

resource "aws_route53_record" "dns_record" {
  zone_id = aws_route53_zone.domain.zone_id
  name    = var.kops_sub_domain
  type    = "NS"
  ttl     = "30"
  records = aws_route53_zone.sub_domain.name_servers
}


resource "aws_s3_bucket" "kops_state" {
  bucket        = "${random_pet.bucket_name.id}-kops-state"
  force_destroy = true
}

resource "random_pet" "bucket_name" {}

/*
Get this below error:--
W0325 07:38:15.726243   30888 executor.go:139] error running task "ManagedFile/discovery.json" (9m55s remaining to succeed): error creating ManagedFile ".well-known/openid-configuration": error writing s3://working-toucan-kops-state/k8s.sundar.cloud/discovery/k8s.sundar.cloud/.well-known/openid-configuration (with ACL="public-read"): AccessControlListNotSupported: The bucket does not allow ACLs
status code: 400, request id: P3R67SMBZZJTTQQJ, host id: xUHP+PZ4iTZ+ceyRgz62cXgZlIanEXKJb2Qzk3cxWNz60jyRqY2QVDsgXt6IpdNkyqg0JSofz4o=

https://github.com/kubernetes/kops/issues/15296

*/

resource "aws_s3_bucket_acl" "prod_media" {
    bucket = aws_s3_bucket.kops_state.id
    acl    = "public-read"
    depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.kops_state.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
  depends_on = [aws_s3_bucket_public_access_block.example]
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.kops_state.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "prod_media_bucket" {
    bucket = aws_s3_bucket.kops_state.id
    policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Principal = "*"
        Action = [
          "s3:*",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.kops_state.id}",
          "arn:aws:s3:::${aws_s3_bucket.kops_state.id}/*"
        ]
      },
      {
        Sid = "PublicReadGetObject"
        Principal = "*"
        Action = [
          "s3:GetObject",
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.kops_state.id}",
          "arn:aws:s3:::${aws_s3_bucket.kops_state.id}/*"
        ]
      },
    ]
  })
  
  depends_on = [aws_s3_bucket_public_access_block.example]
}

resource "tls_private_key" "generic-ssh-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "null_resource" "ssh_key_provisioner" {
  depends_on = [tls_private_key.generic-ssh-key]

  provisioner "local-exec" {
    command = <<EOF
      mkdir -p .ssh/
      echo "${tls_private_key.generic-ssh-key.private_key_openssh}" > .ssh/id_rsa.key
      echo "${tls_private_key.generic-ssh-key.public_key_openssh}" > .ssh/id_rsa.pub
      chmod 400 .ssh/id_rsa.key
      chmod 400 .ssh/id_rsa.pub
    EOF
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
      rm -rvf .ssh/
    EOF
  } 
}



/*
resource "tls_private_key" "generic-ssh-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "null_resource" "ssh_key_provisioner" {
  depends_on = [tls_private_key.generic-ssh-key]

  provisioner "local-exec" {
    command = <<EOF
      mkdir -p .ssh/
      echo "${tls_private_key.generic-ssh-key.private_key_openssh}" > .ssh/id_rsa.key
      echo "${tls_private_key.generic-ssh-key.public_key_openssh}" > .ssh/id_rsa.pub
      chmod 400 .ssh/id_rsa.key
      chmod 400 .ssh/id_rsa.pub
    EOF

    when    = "create"  # This provisioner runs during resource creation
  }

  provisioner "local-exec" {
    command = <<EOF
      rm -rvf .ssh/
    EOF

    when    = "destroy"  # This provisioner runs during resource destruction
  }
}
*/