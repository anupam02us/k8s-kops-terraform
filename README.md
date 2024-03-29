# Kubernetes Kops with Terraform

Kubernetes kops cluster create with the terraform. Here, we use latest Kubernetes version available to `kops` and you can customize several aspects, see below.

## Prerequisites

- [AWS account](https://aws.amazon.com/account/)
- [AWS CLI] $> curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o       "awscliv2.zip"
$> unzip awscliv2.zip
$> sudo ./aws/install
$>aws --version
aws-cli/2.8.2 Python/3.9.11
Note: Little old version also working.

- [Terraform CLI] wget https://releases.hashicorp.com/terraform/1.3.1/terraform_1.3.1_linux_amd64.zip
unzip terraform_1.3.1_linux_amd64.zip
chmod +x terraform
mv terraform /usr/local/bin
export PATH=$PATH:/usr/local/bin
Note: Use latest version of terrafom. Code successfully working with Terraform version v1.7.5. I think,version 1.3.1 will also work.

- [kops CLI] curl -Lo kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x kops
sudo mv kops /usr/local/bin/
- Note: Use latest version of kops.

## Usage

### 1. Define Domain, Sub-Domain, and AWS Region

Customize the following environment variables for your purpose:

```bash
#suppose you select region "eu-central-1" and domain "sundar.cloud" and subdomain k8s.sundar.cloud

#export TF_VAR_kops_domain=sundar.cloud
#export TF_VAR_kops_sub_domain=k8s.sundar.cloud
#export TF_VAR_kops_aws_region=eu-central-1

Note: I want to create cluster on subdomain "k8s.sundar.cloud"
```

### 2 a. AWS Resource Creation with Custom IAM User

Create IAM "kops2" user. All resources(S3 buckets, DNS zones and the EC2 instances) will
create by this user. It is recommendation. But if you want to create all resources with root user(anupam) as per rspl aws account.

It’s recommended to use a non-admin user for creating the kops specific AWS resources like S3 buckets, DNS zones and the EC2 instances. https://kops.sigs.k8s.io/getting_started/aws/

Therefore, first call `terraform` with your admin user account to create an IAM user(kops2) specific for kops.

```bash
export AWS_ACCESS_KEY=$AWS_ACCESS_KEY_ADMIN_USER
export AWS_SECRET_KEY=$AWS_SECRET_KEY_ADMIN_USER

terraform init

#terraform plan  -target=aws_iam_access_key.kops -target=aws_iam_user.kops -target=aws_iam_user_policy.kops_access

#terraform apply  -target=aws_iam_access_key.kops -target=aws_iam_user.kops -target=aws_iam_user_policy.kops_access

terraform plan
terraform apply

output like below:--
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

kops_iam_key = "AKIATG3UFWTEUMRMXKM6"
kops_iam_secret = <sensitive>

Now use kop2 user, to create other resources
```

### 2.b Use the IAM user(kops2) to create all other resources:

```bash
#export AWS_ACCESS_KEY_KOPS_USER=$(terraform output kops_iam_key | tr -d '"')
#export AWS_SECRET_KEY_KOPS_USE=$(terraform output kops_iam_secret | tr -d '"')

Terrafom plan
Terraform apply

Plan output:--
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:
kops_bucket_name = "working-toucan-kops-state"
kops_iam_key = "AKIATG3UFWTE3LX24MXR"
kops_iam_secret = <sensitive>
kops_name_servers = tolist([
  "ns-1137.awsdns-14.org",
  "ns-1935.awsdns-49.co.uk",
  "ns-247.awsdns-30.com",
  "ns-596.awsdns-10.net",
])
  
Note: Create .ssh folder also in the dircroty where keep all files of terraform. 

### 3)  Get the nameserver information and enter them at your registrar:

# terraform output kops_name_servers
kops_name_servers = tolist([
  "ns-1137.awsdns-14.org",
  "ns-1935.awsdns-49.co.uk",
  "ns-247.awsdns-30.com",
  "ns-596.awsdns-10.net",
])

Above result came due to below code:--
output "kops_name_servers" {
  value = tolist(aws_route53_zone.sub_domain.name_servers)
}

Note:--- Here you have to put all above nameserver to your domain registrar. 
Terrafom code created two hosted zone in route53 i) sundar.cloud ii) k8s.sundar.cloud.

You need to add nameserver of "k8s.sundar.cloud" in hostinger.com as I purchase domain(sunder.cloud) purchase form hostinger.com. Change nameserver of domain "sunder.cloud", add all above nameserver which show in terrafom output.
		 
Testing: Create "A" recored under "k8s.sundar.cloud" whcih point to EC2 for testing purpose. Check this, if it work fine, then go for next step. Otherwise wait for DNS propagation. 
```

### 4. AWS Resource Creation with AWS root User(This steps not required)

Not recommended, but you can create all AWS resources with your default AWS root user:

```bash
export AWS_ACCESS_KEY=$AWS_ACCESS_KEY_ADMIN_USER
export AWS_SECRET_KEY=$AWS_SECRET_KEY_ADMIN_USER

terraform init
terraform apply
```

### 5. Cluster Initialization- Here two option(any one can choose)

One-shot installation without any customization:

```bash
#export KOPS_CLUSTER_NAME=$TF_VAR_kops_sub_domain
#export KOPS_BUCKET_NAME=$(terraform output kops_bucket_name | tr -d '"')
#export KOPS_STATE_STORE=s3://${KOPS_BUCKET_NAME}

kops create cluster \
  --name=${KOPS_CLUSTER_NAME} \
  --cloud=aws \
  --ssh-public-key=.ssh/id_rsa.pub \
  --zones=${TF_VAR_kops_aws_region}a \
  --discovery-store=${KOPS_STATE_STORE}/${KOPS_CLUSTER_NAME}/discovery
  --yes
  
---**

```

Or you separate the initialization, customization and building steps:

```bash
	
#export KOPS_CLUSTER_NAME=$TF_VAR_kops_sub_domain
#export KOPS_BUCKET_NAME=$(terraform output kops_bucket_name | tr -d '"')
#export KOPS_STATE_STORE=s3://${KOPS_BUCKET_NAME}	 

kops create cluster \
  --name=${KOPS_CLUSTER_NAME} \
  --cloud=aws \
  --ssh-public-key=.ssh/id_rsa.pub \
  --zones=${TF_VAR_kops_aws_region}a \
  --discovery-store=${KOPS_STATE_STORE}/${KOPS_CLUSTER_NAME}/discovery

If you want to change configuration of cluster:--
kops edit cluster \
  --name=${KOPS_CLUSTER_NAME}

# kops get cluster
NAME                    CLOUD   ZONES
k8s.sundar.cloud        aws     eu-central-1a

To apply cluster:--
kops update cluster  --name k8s.sundar.cloud --yes

Error:--
I0325 01:25:29.859604  156504 executor.go:155] No progress made, sleeping before retrying 2 task(s)
Error: error running tasks: deadline exceeded executing task ManagedFile/discovery.json. Example error: error creating ManagedFile ".well-known/openid-configuration": error writing s3://in-octopus-kops-state/k8s.sundar.cloud/discovery/k8s.sundar.cloud/.well-known/openid-configuration (with ACL="public-read"): AccessControlListNotSupported: The bucket does not allow ACLs
        status code: 400, request id: ZP8BCS1E2XWRFXWT, host id: BQJrEoBe+hRQGr3xnBpt7oc0LScAzY3Az2DA/RdOM7ATrLInTd6Xk3iQYQrPVZGpTokImk5r6lw=
```

### 5. Cluster Access

Use `kops` to get the `kubeconfig` file:

```bash
#kops export kubeconfig --admin
#kops validate cluster --wait 10m 
```

Or access the master node via SSH:

```bash
ssh -i .ssh/id_rsa.key ubuntu@api.${KOPS_CLUSTER_NAME}
```

## 6) Customization (You may skip this steps)

The configuration of a `kops` Kubernetes cluster is contained in a YAML file.  You can configure the Kubernetes version and many other aspects of your cluster, check the [kops documentation](https://kops.sigs.k8s.io/cluster_spec/).

Run this command...

```bash
kops edit cluster --name ${KOPS_CLUSTER_NAME}
````

... and update the cluster:

```bash
kops update cluster --name ${KOPS_CLUSTER_NAME} --yes
```

## 7) Delete the Cluster

Destroy everything:

```bash
# this can take a couple of minutes
kops delete cluster --name ${KOPS_CLUSTER_NAME} --yes

export AWS_ACCESS_KEY=$AWS_ACCESS_KEY_ADMIN_USER
export AWS_SECRET_KEY=$AWS_SECRET_KEY_ADMIN_USER
terraform destroy -auto-approve
```

## Known Bugs

- When installing Kubernetes Version `>1.25.1`, there is a pending `ebs-csi-controller` deployment. On the master node, run `kubectl scale deploy ebs-csi-controller --replicas=1 -n kube-system` to fix it and the cluster should work

-Just note down
 As per document https://kops.sigs.k8s.io/getting_started/aws/, you may add below permisson to kop2 user.
 
AmazonEC2FullAccess
AmazonRoute53FullAccess
AmazonS3FullAccess
IAMFullAccess
AmazonVPCFullAccess
AmazonSQSFullAccess
AmazonEventBridgeFullAccess

- Output of command "kops update cluster --name ${KOPS_CLUSTER_NAME} --yes", may be required sometime.

Cluster configuration has been created.

Suggestions:
 * list clusters with: kops get cluster
 * edit this cluster with: kops edit cluster k8s.sundar.cloud
 * edit your node instance group: kops edit ig --name=k8s.sundar.cloud nodes-eu-central-1a
 * edit your control-plane instance group: kops edit ig --name=k8s.sundar.cloud control-plane-eu-central-1a

Finally configure your cluster with: kops update cluster --name k8s.sundar.cloud --yes --admin

- Note: Keep all output of command when you create cluster, as it may required in the time of delete cluster.

Remember s3 bucket name, required for delete kops cluster
# export KOPS_STATE_STORE=s3://innocent-dog-kops-state
# kops delete cluster --name k8s.sundar.cloud --yes
