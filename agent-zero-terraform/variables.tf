# GCPコンソールで手動作成した IAP OAuth クライアントの認証情報
# 作成場所: APIとサービス → 認証情報 → OAuthクライアントID
variable "iap_oauth_client_id" {
  description = "IAP OAuth client ID (created manually in GCP Console)"
  type        = string
  sensitive   = true
}

variable "iap_oauth_client_secret" {
  description = "IAP OAuth client secret (created manually in GCP Console)"
  type        = string
  sensitive   = true
}
