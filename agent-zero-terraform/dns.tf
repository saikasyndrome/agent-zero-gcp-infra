# ユーザーごとの DNS A レコード（ホスト名 → LB IP）
resource "google_dns_record_set" "agent_zero" {
  for_each = local.users

  name         = "${each.value.domain}."
  type         = "A"
  ttl          = 300
  managed_zone = "YOUR_MANAGED_ZONE" # TODO: replace with your Cloud DNS managed zone short name
  rrdatas      = [google_compute_global_address.lb_ip.address]
}

# Google マネージド SSL 証明書（全ユーザーのドメインをまとめて管理）
resource "google_compute_managed_ssl_certificate" "app" {
  name = "agent-zero-cert"
  managed {
    domains = [for _, user in local.users : user.domain]
  }
}
