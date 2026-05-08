# 初回セットアップ

## 前提条件

- GCP プロジェクト: `YOUR_PROJECT_ID`
- Cloud DNS ゾーン: `YOUR_MANAGED_ZONE`（`YOUR_DOMAIN` 管理）← **事前に作成が必要**
- GCS バケット: `YOUR_BUCKET_NAME`（Terraform state 用）
- IAP 同意画面・OAuth クライアント: GCP コンソールで**事前に手動作成**が必要（下記参照）

---

## 事前準備: Cloud DNS ゾーンについて

### 現在の構成

本構成は既存の Cloud DNS ゾーンを利用してサブドメインを管理します。

| 項目 | 値 |
|---|---|
| ゾーン名（Terraform 参照名） | `YOUR_MANAGED_ZONE` |
| 管理ドメイン | `YOUR_DOMAIN.` |
| ゾーン種別 | 公開 |
| 生成されるサブドメイン例 | `a0.user1.YOUR_DOMAIN` |

Terraform はこのゾーンに対して A レコードを追加するだけです。  
**ゾーン自体は事前に GCP コンソールで作成されている必要があります。**

### 1次ドメイン（親ドメイン）が変わった場合の変更箇所

`YOUR_DOMAIN` が変更になった場合、以下の箇所を修正してください。

| ファイル | 箇所 | 変更内容 |
|---|---|---|
| `k8s-resources.tf` | `locals.users` 各エントリの `domain` | 新ドメインのサブドメインに変更 |
| `dns.tf` | `managed_zone = "YOUR_MANAGED_ZONE"` | 新ゾーン名に変更 |
| `docs/setup.md`（本ファイル） | 前提条件・本セクション | ドキュメント更新 |

**変更例（ドメインを変更した場合）:**

```hcl
# k8s-resources.tf
"user1" = {
  domain = "a0.user1.new-domain.com"
  ...
}

# dns.tf
managed_zone = "new-zone-name"
```

---

## 事前準備: OAuth 同意画面と OAuth クライアントの作成

Terraform apply の前に GCP コンソールで以下を手動で作成してください。

### 1. OAuth 同意画面の設定

`APIとサービス` → `OAuth 同意画面`

| 項目 | 設定値 |
|---|---|
| ユーザーの種類 | 内部（社内利用）または 外部（テスト） |
| アプリ名 | 任意 |

> **テスト環境（外部）の場合**  
> 公開ステータスが「テスト」の間はアクセスできるユーザーが制限されます。  
> `テストユーザー` の欄に、IAP でアクセスさせたい全員のメールアドレスを登録してください。  
> 登録されていないアカウントでアクセスすると `403` になります。

### 2. OAuth クライアント ID の作成

`APIとサービス` → `認証情報` → `認証情報を作成` → `OAuth クライアント ID`

| 項目 | 設定値 |
|---|---|
| アプリケーションの種類 | **ウェブ アプリケーション** |
| 名前 | 任意 |
| 承認済みリダイレクト URI | `https://iap.googleapis.com/v1/oauth/clientIds/<クライアントID>:handleRedirect` |

> **リダイレクト URI について**  
> IAP が認証後にユーザーをリダイレクトするエンドポイントです。  
> クライアント ID 作成後に表示される ID を使って上記 URI を構成し、同じクライアントの編集画面で追加してください。  
> URI の形式: `https://iap.googleapis.com/v1/oauth/clientIds/【ここにクライアントID】:handleRedirect`

作成後に表示される **クライアント ID** と **クライアントシークレット** を控えておいてください。

---

## 必要な IAM ロール

`terraform apply` を実行するアカウントに以下のロールが必要です。

| ロール | ID | 用途 |
|---|---|---|
| 編集者 | `roles/editor` | VPC・サブネット・Cloud NAT・グローバル IP・GCS・SSL 証明書などの基本リソース操作 |
| Kubernetes Engine 管理者 | `roles/container.admin` | GKE クラスター・ノードプールの作成・管理 |
| プロジェクト IAM 管理者 | `roles/resourcemanager.projectIamAdmin` | サービスアカウントへのロール付与（`iam.tf`）・IAP IAM バインディング（`iap.tf`） |
| IAP ポリシー管理者 | `roles/iap.admin` | IAP の有効化・設定 |
| DNS 管理者 | `roles/dns.admin` | Cloud DNS への A レコード追加（`dns.tf`） |
| サービスアカウント管理者 | `roles/iam.serviceAccountAdmin` | GKE ノード用サービスアカウントの作成（`iam.tf`） |

> **最小権限の考え方**  
> `roles/editor` は広範な権限を含むため、本番環境では個別ロールへの分割を推奨します。詳細は [改善点](./improvements.md) を参照してください。

## terraform.tfvars の設定

IAP OAuth クライアントの認証情報を `terraform.tfvars` に記載します。

```hcl
iap_oauth_client_id     = "XXXXXXXXXX-XXXX.apps.googleusercontent.com"
iap_oauth_client_secret = "GOCSPX-XXXXXXXXXXXXXXXXXXXXXXXX"
```

OAuth クライアントの取得場所: `GCP コンソール` → `APIとサービス` → `認証情報` → 該当クライアントの詳細

> ⚠️ `terraform.tfvars` にはシークレットが含まれるため、`.gitignore` に追加して Git 管理対象外にしてください。

## デプロイ手順

```bash
cd agent-zero-terraform

# 初期化
terraform init

# ステップ 1: VPC・サブネットを作成
terraform apply -target=module.vpc

# ステップ 2: GKE クラスターを作成
terraform apply -target=module.gke

# ステップ 3: 残り全て（Kubernetes リソース・IAP・DNS・SSL 証明書・LB 等）
terraform apply
```

> **3 ステップに分ける理由**
>
> | ステップ | 理由 |
> |---|---|
> | VPC を先に作成 | GKE クラスターがサブネットを参照するため、VPC が先に存在している必要がある |
> | GKE を次に作成 | `kubernetes_manifest`（BackendConfig）は plan 時にクラスターへの接続が必要なため、GKE が先に存在している必要がある |
> | 残りをまとめて適用 | GKE 作成後は依存関係が解消されるため、残りは一括 apply が可能 |

## SSL 証明書のアクティブ化確認

```bash
gcloud compute ssl-certificates describe agent-zero-cert --global
```

`status: ACTIVE` になるまで数分〜数十分かかります。その後アクセス可能になります。

## 全リソースの削除

```bash
# Helm リリースを先に削除
helm uninstall agent-zero-user1

# Terraform リソースを削除
terraform destroy
```
