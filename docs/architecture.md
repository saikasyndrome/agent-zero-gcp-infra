# アーキテクチャ

```
インターネット
     ↓
HTTPS ロードバランサ（グローバル静的 IP）
     ↓  Google マネージド SSL 証明書
IAP（Identity-Aware Proxy）
     ↓  認証済みユーザーのみ通過
Ingress（ホストベースルーティング）
     ├── a0.user1.YOUR_DOMAIN   → Service: agent-zero-user1   → Pod (user=user1)
     └── a0.user2.YOUR_DOMAIN   → Service: agent-zero-user2   → Pod (user=user2)
```

- GKE ノードはプライベートノード（外部 IP なし）
- Cloud NAT 経由でのみ外部への通信が可能
- Pod への直接アクセスは不可

## ファイル構成

| ファイル | 役割 |
|---|---|
| `version.tf` | Terraform バージョン・プロバイダー定義、共通 locals |
| `backend.tf` | Terraform state の GCS バックエンド設定 |
| `network.tf` | VPC・サブネット・Cloud NAT・LB 用グローバル IP |
| `k8s-engine.tf` | GKE プライベートクラスター定義 |
| `k8s-resources.tf` | **ユーザー定義**・BackendConfig・Service・Ingress |
| `dns.tf` | Cloud DNS A レコード・Google マネージド SSL 証明書 |
| `iap.tf` | IAP API 有効化・ユーザーごとの IAM バインディング |
| `variables.tf` | IAP OAuth クライアント ID/シークレット変数定義 |
| `terraform.tfvars` | 変数の実値（Git 管理対象外推奨） |

## ユーザー個別環境の実装方式

本構成では、以下の 2 つのレイヤーを組み合わせてユーザーごとの完全に独立した環境を実現しています。

### 1. サブドメイン × IAP によるアクセス分離

ユーザーごとに専用のサブドメインを割り当て、それぞれに独立した IAP バックエンドを構成しています。

```
a0.user1.YOUR_DOMAIN   → BackendConfig-user1   → IAP（user1 のみアクセス可）→ Pod-user1
a0.user2.YOUR_DOMAIN   → BackendConfig-user2   → IAP（user2 のみアクセス可）→ Pod-user2
```

IAP により Google アカウント認証を強制し、`locals.users` に登録されたメールアドレスのみが対応するサブドメインにアクセスできます。他のユーザーのサブドメインには IAP レベルで遮断されます。

### 2. Kubernetes 環境変数によるアプリログイン設定

各ユーザーの Pod には Helm の `values-<user>.yaml` を通じて Agent Zero のログイン情報を環境変数として個別に渡します。

```yaml
env:
  - name: AUTH_LOGIN     # Agent Zero へのログインユーザー名
    value: "admin"
  - name: AUTH_PASSWORD  # Agent Zero へのログインパスワード（ユーザーごとに変更）
    value: "YOUR_PASSWORD"
```

これにより、同じ Agent Zero イメージを使いながら、ユーザーごとに独立した認証情報・データ領域（PVC）を持つ環境が実現されています。

| 分離レイヤー | 手段 | 効果 |
|---|---|---|
| ネットワークアクセス | サブドメイン + IAP | 他ユーザーのサブドメインへのアクセスを Google 認証で遮断 |
| アプリログイン | 環境変数（`AUTH_LOGIN` / `AUTH_PASSWORD`） | Pod ごとに独立したログイン情報 |
| データ | PVC（ユーザーごとに独立） | agents・knowledge・logs 等のデータが混在しない |

---

## 現在の機能

- **ホストベースルーティング**: ユーザーごとの専用サブドメインで振り分け
- **IAP 認証**: Google アカウントで認証済みのユーザーのみアクセス可能
- **Google マネージド SSL 証明書**: ドメイン検証・更新を Google が自動管理
- **Cloud DNS 自動設定**: `YOUR_MANAGED_ZONE` ゾーンへの A レコードを Terraform で管理
- **プライベート GKE クラスター**: ノードへの直接アクセスを遮断
- **Cloud NAT**: プライベートノードからの外部通信（Docker イメージ pull 等）を許可
- **ユーザー単位の IAP アクセス制御**: `extra_emails` で追加許可メールの設定が可能
- **Terraform state の GCS 管理**: `YOUR_BUCKET_NAME` バケットで状態を一元管理
- **ローリングアップデート保護**: Deployment の `maxUnavailable: 0` / `maxSurge: 1` により、アプリ更新時に Pod がゼロになることを防止（※ノードドレイン時の保護は PDB が別途必要。[改善点](./improvements.md) 参照）
