locals {
  app_name = "agent-zero"

  # ユーザーの追加・削除はここで管理する
  # extra_emails: そのユーザーの /<name> パスへのアクセスを追加で許可するメール一覧
  users = {
    "user1" = {
      email        = "YOUR_EMAIL"  # TODO: replace with the user's Google account email
      port         = 80
      domain       = "YOUR_DOMAIN" # TODO: replace with the user's subdomain
      extra_emails = []
    }
    #"user2" = {
    #  email        = "YOUR_EMAIL"  # TODO: replace with the user's Google account email
    #  port         = 8080
    #  domain       = "YOUR_DOMAIN" # TODO: replace with the user's subdomain
    #  extra_emails = []
    #}
  }

  # 各ユーザーの IAP アクセス許可メール一覧をフラット化（本人 + extra_emails）
  user_iap_members = flatten([
    for key, user in local.users : [
      for email in concat([user.email], user.extra_emails) : {
        user_key = key
        email    = email
      }
    ]
  ])
}


# ─────────────────────────────────────────
# IAP OAuth シークレット（全 BackendConfig で共有）
# ─────────────────────────────────────────

resource "kubernetes_secret_v1" "iap_oauth_secret" {
  metadata {
    name      = "iap-oauth-secret"
    namespace = "default"
  }

  data = {
    client_id     = var.iap_oauth_client_id
    client_secret = var.iap_oauth_client_secret
  }

  depends_on = [module.gke]
}

# ─────────────────────────────────────────
# ユーザーごとの BackendConfig（IAP を有効化）
# ステップ 2 の apply 時のみ実行（クラスター作成後）
# ─────────────────────────────────────────

resource "kubernetes_manifest" "backend_config" {
  for_each = local.users

  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "iap-backend-config-${each.key}"
      namespace = "default"
    }
    spec = {
      iap = {
        enabled = true
        oauthclientCredentials = {
          secretName = kubernetes_secret_v1.iap_oauth_secret.metadata[0].name
        }
      }
      healthCheck = {
        checkIntervalSec   = 15
        timeoutSec         = 5
        healthyThreshold   = 1
        unhealthyThreshold = 2
        type               = "HTTP"
        requestPath        = "/api/health"
        port               = each.value.port
      }
    }
  }

  depends_on = [module.gke, kubernetes_secret_v1.iap_oauth_secret]
}

# ─────────────────────────────────────────
# ユーザーごとの Service
# ─────────────────────────────────────────

resource "kubernetes_service_v1" "user" {
  for_each = local.users

  metadata {
    name      = "${local.app_name}-${each.key}"
    namespace = "default"
    annotations = {
      "cloud.google.com/backend-config" = jsonencode({ default = "iap-backend-config-${each.key}" })
      "cloud.google.com/neg"            = jsonencode({ ingress = true })
    }
  }

  spec {
    # Pod に app + user ラベルを付けてユーザーごとに振り分ける
    selector = {
      app  = local.app_name
      user = each.key
    }

    port {
      port        = 80
      target_port = each.value.port
    }

    type = "ClusterIP"
  }

  depends_on = [module.gke, kubernetes_manifest.backend_config]
}

# ─────────────────────────────────────────
# 単一 Ingress - ユーザーごとのパスベースルーティング
# インターネット → LB → Ingress → /<user>/* → Service-<user> → Pod
# ─────────────────────────────────────────

resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = "${local.app_name}-ingress"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                 = "gce"
      "kubernetes.io/ingress.global-static-ip-name" = google_compute_global_address.lb_ip.name
      "kubernetes.io/ingress.allow-http"            = "false"
      # Google マネージド SSL 証明書を使用（自己署名証明書の代わり）
      "ingress.gcp.kubernetes.io/pre-shared-cert"   = google_compute_managed_ssl_certificate.app.name
    }
  }

  spec {
    dynamic "rule" {
      for_each = local.users
      content {
        # ホストベースルーティング: ユーザーごとのドメインで振り分ける
        host = rule.value.domain
        http {
          path {
            path      = "/"
            path_type = "Prefix"
            backend {
              service {
                name = "${local.app_name}-${rule.key}"
                port { number = 80 }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    module.gke,
    kubernetes_service_v1.user,
    kubernetes_manifest.backend_config,
    google_compute_managed_ssl_certificate.app,
  ]
}

# ─────────────────────────────────────────
# Output
# ─────────────────────────────────────────

output "load_balancer_ip" {
  description = "ロードバランサのグローバル IP アドレス"
  value       = google_compute_global_address.lb_ip.address
}

output "user_access_urls" {
  description = "ユーザーごとのアクセス URL"
  value = {
    for key, user in local.users :
    key => "https://${user.domain}/"
  }
}
