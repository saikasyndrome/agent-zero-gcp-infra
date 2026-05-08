data "google_client_config" "default" {}

locals {
  # Kubernetes API サーバー（kubectl 等）へのアクセスを許可する CIDR 一覧
  # TODO: replace with the CIDR ranges you want to allow
  master_authorized_networks = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "authorized-network"
    }
  ]

  gke_clusters = {
    "gke-cluster-1" = {
      project_id                 = local.gc_project_id
      region                     = local.default_region
      zones                      = [local.default_zone]
      network                    = local.vpc_networks["main-vpc"].network_name
      subnetwork                 = local.vpc_networks["main-vpc"].subnets[0].subnet_name
      ip_range_pods              = local.vpc_networks["main-vpc"].secondary_ranges["main-subnet"][0].range_name
      ip_range_services          = local.vpc_networks["main-vpc"].secondary_ranges["main-subnet"][1].range_name
      http_load_balancing        = true # GKE Ingress（L7 LB）を使用するために必須
      network_policy             = true # Pod レベルのトラフィック制御を有効化
      horizontal_pod_autoscaling = true
      filestore_csi_driver       = false
      dns_cache                  = false

      # プライベートクラスター - ノードに外部 IP を付与しない
      enable_private_nodes    = true
      enable_private_endpoint = false # true にすると API サーバーへの外部アクセスも遮断される
      master_ipv4_cidr_block  = "172.16.0.0/28"

      node_pools = [
        {
          name               = "test-node-pool"
          machine_type       = "e2-medium"
          node_locations     = local.default_zone
          min_count          = 1
          max_count          = 3
          local_ssd_count    = 0
          spot               = false
          disk_size_gb       = 50
          disk_type          = "pd-standard"
          image_type         = "COS_CONTAINERD"
          enable_gcfs        = false
          enable_gvnic       = false
          logging_variant    = "DEFAULT"
          auto_repair        = true
          auto_upgrade       = true
          service_account    = google_service_account.service_accounts["a0-backend-sa"].email
          preemptible        = false
          initial_node_count = 1
        },
      ]

      node_pools_oauth_scopes = {
        all = [
          "https://www.googleapis.com/auth/logging.write",
          "https://www.googleapis.com/auth/monitoring",
          "https://www.googleapis.com/auth/devstorage.read_only",
        ]
      }
    }
  }
}

module "gke" {
  for_each = local.gke_clusters

  source                     = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version                    = "~> 44.0"
  project_id                 = each.value.project_id
  create_service_account     = false
  name                       = each.key
  region                     = each.value.region
  zones                      = each.value.zones
  network                    = each.value.network
  subnetwork                 = each.value.subnetwork
  ip_range_pods              = each.value.ip_range_pods
  ip_range_services          = each.value.ip_range_services
  http_load_balancing        = each.value.http_load_balancing
  network_policy             = each.value.network_policy
  horizontal_pod_autoscaling = each.value.horizontal_pod_autoscaling
  filestore_csi_driver       = each.value.filestore_csi_driver
  dns_cache                  = each.value.dns_cache

  enable_private_nodes    = each.value.enable_private_nodes
  enable_private_endpoint = each.value.enable_private_endpoint
  master_ipv4_cidr_block  = each.value.master_ipv4_cidr_block

  master_authorized_networks = local.master_authorized_networks

  node_pools              = each.value.node_pools
  node_pools_oauth_scopes = each.value.node_pools_oauth_scopes
}

provider "kubernetes" {
  host                   = "https://${module.gke["gke-cluster-1"].endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke["gke-cluster-1"].ca_certificate)
}
