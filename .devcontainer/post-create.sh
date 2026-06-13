#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.kube"

echo "Tool versions:"
kubectl version --client --output=yaml | head -n 8 || true
helm version || true
kustomize version || true
argocd version --client || true
