# k8slab

## Starting a Cluster

```
cd terraform
terraform init
terraform apply
```

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


## Generate token for SA used in GH actions (not implemented yet)


```
kubectl create token k8slab -n k8slab
```

## TODO:

- github action applying helm chart
- versioning for goapp (release on tags etc...)
- Adding RDS to terraform, injecting RDS password as secret to k8s, implementing DB in goapp