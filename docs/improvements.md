# 改善点・TODO

## Kubernetes

| 優先度 | 項目 | 内容 |
|---|---|---|
| 🔴 高 | Liveness / Readiness Probe の追加 | 現在 Probe が未設定のため、Pod が起動直後にトラフィックを受けたり、ハング時に自動再起動されない。Agent Zero の起動完了エンドポイント（例: `/api/health`）を基に設定が必要 |
| 🔴 高 | Startup Probe の追加 | Agent Zero は初回起動に時間がかかる可能性があるため、Startup Probe で起動完了を待ってから Liveness チェックを開始する設計が望ましい |
| 🟡 中 | PVC 容量の最適化 | 現在全ユーザー一律 `10Gi` に設定。ユーザーごとの実際の使用量（agents・knowledge・logs 等）を計測し、適切な容量に見直すことでストレージコストを削減できる |
| 🟡 中 | HPA（水平スケーリング）の最適化 | 現在 `replicaCount` が固定。CPU / メモリ使用率に応じて自動スケールする HorizontalPodAutoscaler を有効化し、`minReplicas`・`maxReplicas`・しきい値を実測ベースで調整する |
| 🟡 中 | VPA（垂直スケーリング）の検討 | HPA と組み合わせて VPA（VerticalPodAutoscaler）を導入することで、Pod の `requests/limits` を自動調整し、過剰なリソース確保を防止できる |
| 🟡 中 | Resource requests / limits の調整 | 現在 `cpu: 100m / memory: 512Mi`（request）に設定済みだが、Agent Zero の実測値をもとに適切な値に見直す。過小設定はノードの OOM を引き起こすリスクがある |
| 🟢 低 | PodDisruptionBudget の改善 | Deployment の `maxUnavailable: 0` でローリングアップデート時は保護済み。ただし GKE ノードのアップグレード（drain）時には PDB が別途必要。現在 `replicaCount: 1` のため、先に HPA で最低 2 レプリカを確保した上で `minAvailable: 1` の PDB を設定することを推奨 |
| 🟢 低 | Affinity / Anti-affinity の設定 | 複数ユーザーの Pod が同一ノードに集中しないよう、Pod Anti-affinity で分散配置を促す |
| 🟢 低 | 監視・ロギングスタックの導入 | 現在は GKE デフォルトのロギングのみ。本番運用を見据えて Prometheus（メトリクス収集）+ Grafana（可視化・アラート）+ Loki（ログ集約）の導入を推奨。Helm chart（kube-prometheus-stack）で一括デプロイ可能 |

## Terraform（インフラ・コスト最適化）

| 優先度 | 項目 | 内容 |
|---|---|---|
| 🔴 高 | `master_authorized_networks` を制限 | 現在 `0.0.0.0/0`（全許可）。実際に使用する IP 帯域に絞ること |
| 🟡 中 | ノードプールの分離（システム / サービス） | 現在全 Pod が単一ノードプールで稼働。`kube-system` 系のシステム Pod とユーザー向けサービス Pod を別ノードプールに分離することで、スペックやスケーリングポリシーを独立して最適化できる。例: システム用に小型固定ノード、サービス用に Spot インスタンスを活用したオートスケール構成 |
| 🟡 中 | Spot インスタンスの活用 | 現在 `spot = false`。サービスノードプールで Spot インスタンス（`spot = true`）を使用することで、コストを最大 60〜90% 削減できる。Spot 対応には PDB と複数レプリカの設定が必要 |
| 🟡 中 | ノードプールのマシンタイプ最適化 | 現在 `e2-medium`（vCPU 2 / メモリ 4GB）を全ユーザー共有で使用。Agent Zero のメモリ使用量が多い場合、`e2-highmem-2`（vCPU 2 / メモリ 16GB）や `e2-standard-4` への変更を検討する |
| 🟡 中 | apply に必要な IAM ロールの最小化 | 現在 `roles/editor`（広範）を使用。以下の個別ロールに絞ることで最小権限を実現できる: `roles/compute.networkAdmin`・`roles/compute.securityAdmin`・`roles/storage.objectAdmin`・`roles/serviceusage.serviceUsageAdmin`・`roles/container.admin`・`roles/resourcemanager.projectIamAdmin`・`roles/iam.serviceAccountAdmin`・`roles/dns.admin`・`roles/iap.admin` |
| 🟡 中 | IAP のパスレベル分離 | 現状は IAP の IAM 権限がプロジェクト全体に適用される。厳密な分離には `X-Goog-Authenticated-User-Email` ヘッダーをアプリ側で検証する必要がある |
| 🟡 中 | GKE モジュールのバージョンアップ | 現在 `~> 44.0` で `kubernetes_config_map` Deprecated 警告が出ている。v45 以降のリリース後にアップグレード |
| 🟢 低 | Helm chart の Terraform 管理化 | 現在 Helm デプロイは手動。`helm_release` リソースで Terraform に統合することで完全自動化が可能 |
