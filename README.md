# k8slab

New version is published to docker hub on tag creation. Tag has to start with letter v. After tagging new image gets published and helm upgrade is being ran.


## Starting a Cluster

Before starting terraform apply please setup authentication for bot AWS and github provider. Github AUTH eg (export GITHUB_TOKEN=....) is needed as terraform will automatically create kubeconfig secret which is needed in github actions during helm runs.


```
cd terraform
terraform init
## VPC must exist before creation of eks - caused by dependency
terraform apply -target=module.vpc
terraform apply 
```

And this is it, running github action should install helm chart on the cluster. All config data should be available in github action secrets at this point. 




## Setting kube config

```
aws eks update-kubeconfig --name k8slab
```

## Deploy helm

```
cd helm
helm install/upgrade k8slab ./goapp --namespace k8slab
```

## Accessing

Check newly created alb in aws:

```
aws elbv2 describe-load-balancers | grep DNSName                       
            "DNSName": "k8s-k8slab-k8slabgo-704fc62c50-1091289972.eu-west-1.elb.amazonaws.com",
```

or k8s cluster:

```
➜ kubectl describe ingress k8slab-goapp -n k8slab | grep Address
Address:          k8s-k8slab-k8slabgo-704fc62c50-1091289972.eu-west-1.elb.amazonaws.com
```

In case of dns error wait a few minutes. It takes time for ALB to become available on the Internet.

## Destroy

Prior to destroying with terraform, uninstall helm chart. Without this ALB ingress controller will not remove ALB for you and this will have to be done manually.


```
helm uninstall k8slab -n k8slab

```

Now it is safe to remove terraformed resources.


```
terraform destroy
```