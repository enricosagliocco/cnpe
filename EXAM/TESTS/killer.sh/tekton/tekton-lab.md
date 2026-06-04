# Tekton Pipelines — Lab CNPE (Kubernetes 1.33)

Laboratorio CI/CD nativo Kubernetes: **Task**, **Pipeline**, **PipelineRun**, workspaces, RBAC e troubleshooting.

| File | Ruolo |
|------|--------|
| [questions/setup-lab.sh](questions/setup-lab.sh) | Minikube + Tekton + scenario rotto |
| [questions/domande.md](questions/domande.md) | 20 domande stile esame Killer Shell (senza risposte) |
| [questions/risposte.md](questions/risposte.md) | 20 risposte |

```bash
export LAB_DIR="$HOME/course/tekton-lab"
chmod +x questions/setup-lab.sh
./questions/setup-lab.sh
# ./questions/setup-lab.sh --cleanup
```

---

## Architettura del lab

| Namespace | Contenuto |
|-----------|-----------|
| `tekton-pipelines` | Controller, webhook, Dashboard |
| `builder` | Task, Pipeline, PipelineRun, SA `pipeline-runner` |
| `team-*` | Namespace creati dalle pipeline di onboarding |
| `team-sandwich` | Pod `crypto-miner` per esercizio scan |

### Pipeline

| Nome | Scopo |
|------|--------|
| `cnpe-release` | fetch → build → deploy (+ finally notify) |
| `cnpe-team-onboard` | crea NS team + RoleBinding view |
| `cnpe-policy-scan` | doppio scan grep su Pod YAML |

### Bug introdotti (da correggere)

| Risorsa | Problema |
|---------|----------|
| `cnpe-build-image` | `$(params.git-revision)` vs `gitRevision` |
| `cnpe-release` | `runAfter: checkout`; `when` su `build-image` |
| `pipelinerun-release` | SA `tekton-bot`; workspace `emptyDir` |
| `pipeline-runner-binding` | subject SA in `default` |
| `cnpe-policy-scan` | task `scan-b` usa `forbidden1` due volte |

---

## Prerequisiti

- `kubectl`, `minikube`
- Opzionale: `tkn` CLI (lo script tenta l’installazione)

Tekton installato da release **v0.68.0** (compatibile K8s 1.33). Dashboard NodePort **30220** (override: `DASHBOARD_NODEPORT=...`).

---

## Flusso troubleshooting

1. Controller Tekton Ready  
2. Correggere **RBAC** (`pipeline-runner`)  
3. Correggere **Task** (parametri/script)  
4. Correggere **Pipeline** (`runAfter`, `when`, scan-b)  
5. Eseguire **PipelineRun** con SA e workspace corretti  
6. Onboard team → scan team-sandwich → cleanup run falliti  

---

## Comandi utili

```bash
tkn -n builder tasks list
tkn -n builder pipelines list
tkn -n builder pipelinerun describe <name>
kubectl -n builder get taskrun -o wide
```

Port-forward Dashboard (esame):

```bash
kubectl -n tekton-pipelines port-forward --address 0.0.0.0 svc/tekton-dashboard 30220:9097
```

---

## Documentazione

| Argomento | Link |
|-----------|------|
| Pipelines overview | https://tekton.dev/docs/pipelines/ |
| PipelineRuns | https://tekton.dev/docs/pipelines/pipelineruns/ |
| Workspaces | https://tekton.dev/docs/pipelines/workspaces/ |
| Authentication/RBAC | https://tekton.dev/docs/pipelines/auth/ |
| tkn CLI | https://tekton.dev/docs/cli/ |

---

## Confronto lab CNPE

| Lab | Focus |
|-----|--------|
| [storage](../storage/storage-test.md) | PVC, StorageClass |
| [quota-network](../quota-network/quota-network-policy-test.md) | Quota, NetworkPolicy |
| [gatekeeper](../gatekeeper/gatekeeper-lab.md) | OPA admission |
| **questo lab** | Tekton CI/CD |

Riferimento esame: `exam01` Q12, `exam02` Q4.

---

## Cleanup

```bash
./questions/setup-lab.sh --cleanup
```

Per rimuovere Tekton:

```bash
kubectl delete -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.68.0/release.yaml
```
