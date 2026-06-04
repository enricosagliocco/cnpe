# CNPE Gitea Exam-like Lab 2

Contiene:
- `setup-cnpe-gitea-examlike.sh`: crea cluster Minikube, repo Gitea, Argo CD, Prometheus minimale, Flagger, Tekton e workload rotti.
- `domande-cnpe-gitea-examlike.md`: batteria esame da 12 task, stile performance-based.

Uso:
```bash
chmod +x setup-cnpe-gitea-examlike.sh
./setup-cnpe-gitea-examlike.sh
```

Override principali:
```bash
export GITEA_URL="http://192.168.1.56:3000/"
export GITEA_TOKEN="d2fcd54b7a8e2762920d929bfd4456db208659e4"
export GITEA_USER="cnpe-user"
export GITEA_PASS="cnpe-pass"
export GITEA_ORG="organization"
```

Cleanup:
```bash
./setup-cnpe-gitea-examlike.sh --cleanup
```
