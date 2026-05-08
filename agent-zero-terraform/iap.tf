resource "google_project_service" "iap" {
  project            = local.gc_project_id
  service            = "iap.googleapis.com"
  disable_on_destroy = false
}

# ユーザーごとの IAP IAM 権限付与
# local.user_iap_members でフラット化した「ユーザーキー + メール」のリストを使用
# extra_emails に追加したメールも同じパスにアクセス可能になる
resource "google_iap_web_iam_member" "user" {
  for_each = {
    for m in local.user_iap_members :
    "${m.user_key}--${m.email}" => m
  }

  project = local.gc_project_id
  role    = "roles/iap.httpsResourceAccessor"
  member  = "user:${each.value.email}"

  depends_on = [google_project_service.iap]
}
