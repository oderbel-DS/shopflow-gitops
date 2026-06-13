# ShopFlow GitOps

Ce depot est la source de verite du deploiement Kubernetes de ShopFlow.

- Le code applicatif (backend/frontend) vit dans le depot `shopflow`.
- Le deploiement (ArgoCD + Helm + values par environnement) vit dans ce depot `shopflow-gitops`.

## Architecture

Structure principale:

- `apps/`
  - Applications ArgoCD (App of Apps)
  - `argocd-root-app.yaml` deploie les autres applications ArgoCD
  - `argocd-shopflow-staging.yaml` deploie staging
  - `argocd-shopflow-prod.yaml` deploie prod
- `charts/shopflow/`
  - Chart Helm de l'application ShopFlow
- `envs/staging/values-staging.yaml`
  - Surcharges Helm pour staging
- `envs/prod/values-prod.yaml`
  - Surcharges Helm pour prod

## Comment le deploiement fonctionne

1. Build image dans le depot applicatif `shopflow`
- Le workflow CI backend construit l'image Docker.
- Il pousse l'image dans Artifact Registry:
  - `northamerica-northeast2-docker.pkg.dev/shopflow-499020/shopflow/backend`
- Il genere un tag de type `sha-xxxxxxx`.

2. Mise a jour GitOps automatique (staging)
- La CI met a jour `envs/staging/values-staging.yaml` avec le nouveau tag image.
- Elle commit/push dans ce depot gitops.

3. Detection par ArgoCD
- ArgoCD surveille ce depot.
- A chaque commit, ArgoCD detecte le drift entre Git et le cluster.

4. Rendu Helm puis application Kubernetes
- ArgoCD lit:
  - le chart `charts/shopflow`
  - les values d'environnement (`envs/staging/...` ou `envs/prod/...`)
- Helm rend les manifests Kubernetes.
- ArgoCD applique les manifests sur le cluster.

5. Rollout du Deployment
- Le Deployment est mis a jour avec la nouvelle image (`repository + tag`).
- Kubernetes declenche le rollout progressif des pods.

## Fichiers ArgoCD importants

- `apps/argocd-root-app.yaml`
  - point d'entree App of Apps
- `apps/argocd-shopflow-staging.yaml`
  - source chart: `charts/shopflow`
  - values: `../../envs/staging/values-staging.yaml`
  - namespace: `shopflow-staging`
- `apps/argocd-shopflow-prod.yaml`
  - source chart: `charts/shopflow`
  - values: `../../envs/prod/values-prod.yaml`
  - namespace: `shopflow-prod`

## Gestion des images

Valeurs utilisees actuellement:

- Repository image:
  - `northamerica-northeast2-docker.pkg.dev/shopflow-499020/shopflow/backend`
- Tag image:
  - defini par environnement dans `envs/staging/values-staging.yaml` et `envs/prod/values-prod.yaml`

## Promotion recommandee

Mode professionnel recommande:

1. Staging automatique
- CI met a jour le tag en staging apres build/tests/scan.

2. Prod manuelle
- Promotion via PR dans ce depot:
  - copier le tag valide de staging vers prod
  - review + approbation
  - merge
- ArgoCD deploie prod apres le merge.

## Commandes utiles

Verifier les tags images disponibles:

```bash
gcloud artifacts docker tags list \
  northamerica-northeast2-docker.pkg.dev/shopflow-499020/shopflow/backend \
  --sort-by=~UPDATE_TIME
```

Verifier l'image deployee:

```bash
kubectl -n shopflow-staging get deploy -o jsonpath='{.items[*].spec.template.spec.containers[*].image}'; echo
kubectl -n shopflow-prod get deploy -o jsonpath='{.items[*].spec.template.spec.containers[*].image}'; echo
```

Verifier ArgoCD:

```bash
argocd app get shopflow-staging
argocd app get shopflow-prod
```
