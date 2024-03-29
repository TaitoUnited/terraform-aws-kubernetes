# AWS Kubernetes

Example usage:

```
provider "aws" {
  region = "us-east-1"
}

module "kubernetes" {
  source              = "TaitoUnited/kubernetes/aws"
  version             = "1.0.0"

  user_profile        = "john.doe"
  email               = "devops@mydomain.com"

  vpc_id              = module.network.vpc_id
  private_subnets     = module.network.private_subnets

  additional_accounts = []

  /* TODO: not required? -> use permissions?
  roles = [
    rolearn  = string
    username = "cicd-role"
    groups   = ["system:masters"]
  ]
  users = [
    userarn  = string
    username = "cicd-user"
    groups   = ["system:masters"]
  ]
  */

  # Permissions
  permissions                = yamldecode(
    file("${path.root}/../infra.yaml")
  )["permissions"]

  # Kubernetes
  kubernetes                 = yamldecode(
    file("${path.root}/../infra.yaml")
  )["kubernetes"]

  # Helm infrastructure apps
  helm_enabled               = false  # Should be false on the first run, then true
  generate_ingress_dhparam   = false
  use_kubernetes_as_db_proxy = true
  postgresql_cluster_names   = [ "my-postgresql-1" ]
  mysql_cluster_names        = [ "my-mysql-1" ]
}
```

Example YAML:

```
# Permissions
permissions:

  # Cluster-wide permissions
  clusterRoles:
    - name: taito-iam-admin
      subjects: [ "ADMINS_GROUP_ID" ]
    - name: taito-status-viewer
      subjects: [ "DEVELOPERS_GROUP_ID" ]

  # Namespace specific permissions
  namespaces:
    - name: common
      clusterRoles:
        - name: taito-secret-viewer
          subjects:
            - DEVELOPERS_GROUP_ID
            - CICD_TESTER_USER_ID
    - name: db-proxy
      clusterRoles:
        - name: taito-pod-portforwarder
          subjects:
            - DEVELOPERS_GROUP_ID
            - CICD_TESTER_USER_ID
    - name: my-namespace
      clusterRoles:
        - name: taito-developer
          subjects:
            - SOME_USER_ID
            - ANOTHER_USER_ID
    - name: another-namespace
      clusterRoles:
        - name: taito-developer
          subjects:
            - SOME_USER_ID
            - ANOTHER_USER_ID

# For Kubernetes setting descriptions, see
# https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/
kubernetes:
  name: zone1-common-kube1
  version: "1.20"

  # Network
  masterAuthorizedNetworks:
    - 0.0.0.0/0

  # Node pools
  nodePools:
    - instanceType: t3.medium
      minNodeCount: 1
      maxNodeCount: 1

  # Certificate managers
  certManager:
    enabled: true

  # Ingress controllers
  ingressNginxControllers:
    - name: ingress-nginx
      class: nginx
      replicas: 3
      metricsEnabled: true
      # MaxMind license key for GeoIP2: https://support.maxmind.com/account-faq/license-keys/how-do-i-generate-a-license-key/
      maxmindLicenseKey:
      # Map TCP/UDP connections to services
      tcpServices:
        3000: my-namespace/my-tcp-service:9000
      udpServices:
        3001: my-namespace/my-udp-service:9001
      # See https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/
      configMap:
        # Hardening
        # See https://kubernetes.github.io/ingress-nginx/deploy/hardening-guide/
        keep-alive: 10
        custom-http-errors: 403,404,503,500
        server-snippet: >
          location ~ /\.(?!well-known).* {
            deny all;
            access_log off;
            log_not_found off;
            return 404;
          }
        hide-headers: Server,X-Powered-By
        ssl-ciphers: EECDH+AESGCM:EDH+AESGCM
        enable-ocsp: true
        hsts-preload: true
        ssl-session-tickets: false
        client-header-timeout: 10
        client-body-timeout: 10
        large-client-header-buffers: 2 1k
        client-body-buffer-size: 1k
        proxy-body-size: 1k
        # Firewall and access control
        enable-modsecurity: true
        enable-owasp-modsecurity-crs: true
        use-geoip: false
        use-geoip2: true
        enable-real-ip: false
        whitelist-source-range: ""
        block-cidrs: ""
        block-user-agents: ""
        block-referers: ""

  # TIP: You can install more infrastructure apps on your Kubernetes with:
  # https://github.com/TaitoUnited/infra-apps-template
```

YAML attributes:

- See variables.tf for all the supported YAML attributes.
- See [Cluster Roles](https://github.com/TaitoUnited/taito-charts/blob/master/kubernetes-admin/templates/clusterrole.yaml) of kubernetes-admin Helm Chart for all predefined role definitions (e.g. taito-developer, taito-status-viewer, taito-secret-viewer).

Combine with the following modules to get a complete infrastructure defined by YAML:

- [Admin](https://registry.terraform.io/modules/TaitoUnited/admin/aws)
- [DNS](https://registry.terraform.io/modules/TaitoUnited/dns/aws)
- [Network](https://registry.terraform.io/modules/TaitoUnited/network/aws)
- [Compute](https://registry.terraform.io/modules/TaitoUnited/compute/aws)
- [Kubernetes](https://registry.terraform.io/modules/TaitoUnited/kubernetes/aws)
- [Databases](https://registry.terraform.io/modules/TaitoUnited/databases/aws)
- [Storage](https://registry.terraform.io/modules/TaitoUnited/storage/aws)
- [Monitoring](https://registry.terraform.io/modules/TaitoUnited/monitoring/aws)
- [Integrations](https://registry.terraform.io/modules/TaitoUnited/integrations/aws)
- [PostgreSQL privileges](https://registry.terraform.io/modules/TaitoUnited/privileges/postgresql)
- [MySQL privileges](https://registry.terraform.io/modules/TaitoUnited/privileges/mysql)

Similar modules are also available for Azure, Google Cloud, and DigitalOcean. All modules are used by [infrastructure templates](https://taitounited.github.io/taito-cli/templates#infrastructure-templates) of [Taito CLI](https://taitounited.github.io/taito-cli/). TIP: See also [AWS project resources](https://registry.terraform.io/modules/TaitoUnited/project-resources/aws), [Full Stack Helm Chart](https://github.com/TaitoUnited/taito-charts/blob/master/full-stack), and [full-stack-template](https://github.com/TaitoUnited/full-stack-template).

Contributions are welcome!
