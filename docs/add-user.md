# ユーザーの追加・削除

## ユーザーの追加

`k8s-resources.tf` の `locals.users` にブロックを 1 つ追加するだけです。

```hcl
users = {
  "user1" = {
    email        = "user1@YOUR_DOMAIN"
    port         = 80
    domain       = "a0.user1.YOUR_DOMAIN"
    extra_emails = []
  }
  # ↓ ここを追加
  "user2" = {
    email        = "user2@YOUR_DOMAIN"
    port         = 80
    domain       = "a0.user2.YOUR_DOMAIN"
    extra_emails = []
    # extra_emails = ["guest@YOUR_DOMAIN"]  # 追加でアクセス許可するメール
  }
}
```

その後 `terraform apply` を実行すると以下が**自動で**作成されます。

| 自動作成されるリソース | 内容 |
|---|---|
| Cloud DNS A レコード | `a0.user2.YOUR_DOMAIN` → LB IP |
| SSL 証明書 | `user2` ドメインが証明書に自動追加 |
| Ingress ルール | `host: a0.user2.YOUR_DOMAIN` |
| Kubernetes Service | `agent-zero-user2` |
| BackendConfig | `iap-backend-config-user2`（IAP 有効） |
| IAP IAM バインディング | `user2@YOUR_DOMAIN` にアクセス権付与 |

最後に Helm で Pod をデプロイします。

### ステップ 1: values ファイルを用意する

ユーザーごとに `values-<user>.yaml` を作成します。

```yaml
# values-user2.yaml

podLabels:
  app: agent-zero
  user: user2          # Terraform の Service selector と一致させる

env:
  - name: API_KEY_GOOGLE
    value: "YOUR_API_KEY"
  - name: AUTH_LOGIN
    value: "admin"
  - name: AUTH_PASSWORD
    value: "YOUR_PASSWORD"

pvc:
  name: agent-zero-pvc-user2      # ユーザーごとに固有の名前にする
  storageClassName: standard-rwo
  storage: 10Gi

volumes:
  - name: agent-data
    persistentVolumeClaim:
      claimName: agent-zero-pvc-user2

service:
  enabled: false        # Service は Terraform で管理するため無効化
```

### ステップ 2: Helm でデプロイする

```bash
helm install agent-zero-user2 ../agent-zero-gke \
  -f values-user2.yaml
```

### Helm デプロイ時の注意点

| 項目 | 注意内容 |
|---|---|
| `podLabels.user` | Terraform の `locals.users` のキーと**完全一致**させること。不一致だと Service がトラフィックを転送できない |
| `pvc.name` | ユーザーごとに異なる名前にすること。同名にすると既存 PVC と競合する |
| `service.enabled` | 必ず `false` にすること。Terraform 管理の Service と競合する |

## ユーザーの削除

`locals.users` から該当ブロックを削除して `terraform apply` を実行します。  
Helm リリースも忘れず削除してください。

```bash
helm uninstall agent-zero-user2
terraform apply
```
