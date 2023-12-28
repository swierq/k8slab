apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${cluster_ca_certificate}
    server: ${host}
  name: ${cluster_arn}
contexts:
- context:
    cluster: ${cluster_arn}
    user: ${name}
    namespace: ${name}
  name: ${name}
current-context: ${name}
kind: Config
preferences: {}
users:
- name: k8slab
  user:
    token: ${token}
