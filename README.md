# Agent Zero GKE Offering

## Agent Zero とは

[Agent Zero](https://github.com/agent0ai/agent-zero) は、事前に特定タスクがプログラムされていない汎用 AI エージェントフレームワークです。

- **コンピューターをツールとして使用**: コードの記述・ターミナル実行・Web 検索・ファイル操作などをエージェント自身が判断して実行
- **マルチエージェント協調**: タスクを分解してサブエージェントに委譲し、階層的に問題を解決
- **永続メモリ**: 過去の解決策・コード・ファクトを記憶し、次回以降のタスクに活用
- **完全カスタマイズ**: システムプロンプト・ツール・プラグインをすべてユーザーが変更可能
- **Web UI**: リアルタイムストリーミング出力、チャット保存・読み込み対応

---

## 本構成で実装していること

Agent Zero をマルチユーザー対応の GKE 環境で安全に提供するための **インフラ基盤** を Terraform + Helm で構成しています。

### 個別環境の分離

ユーザーごとに完全に独立した環境を以下の 2 つのレイヤーで実現しています。

| レイヤー | 手段 | 効果 |
|---|---|---|
| **ネットワークアクセス** | サブドメイン + IAP | Google 認証で他ユーザーのサブドメインへのアクセスを遮断 |
| **アプリログイン** | 環境変数（`AUTH_LOGIN` / `AUTH_PASSWORD`） | Pod ごとに独立したログイン情報 |
| **データ** | PVC（ユーザーごと独立） | agents・knowledge・logs 等のデータが混在しない |

### アクセスフロー

```
インターネット
     ↓
HTTPS ロードバランサ（グローバル静的 IP）
     ↓  Google マネージド SSL 証明書
IAP（Identity-Aware Proxy）← Google アカウント認証
     ↓  登録済みメールのみ通過
Ingress（ホストベースルーティング）
     ├── a0.user1.YOUR_DOMAIN   → Pod: Agent Zero (user=user1)
     └── a0.user2.YOUR_DOMAIN   → Pod: Agent Zero (user=user2)
```

### 構成要素

| 要素 | 技術 | 役割 |
|---|---|---|
| インフラ管理 | Terraform | GKE・VPC・DNS・IAP・SSL 証明書を IaC で管理 |
| アプリデプロイ | Helm | ユーザーごとの Agent Zero Pod を個別にデプロイ |
| 認証・認可 | Google IAP | サブドメイン単位でアクセスユーザーを制限 |
| データ永続化 | GKE PVC | ユーザーごとの作業データを永続保存 |
| ネットワーク | プライベート GKE + Cloud NAT | ノードへの直接アクセスを遮断 |

---

## ドキュメント

- [アーキテクチャ・機能一覧](./docs/architecture.md)
- [初回セットアップ](./docs/setup.md)
- [ユーザーの追加・削除](./docs/add-user.md)
- [改善点・TODO](./docs/improvements.md)
