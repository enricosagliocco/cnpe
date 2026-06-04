# CNPE Exam-like Lab Pack

Contiene:

- `setup-cnpe-examlike.sh`: setup ambiente Minikube multi-dominio.
- `domande-cnpe-examlike.md`: 20 task performance-based.
- `README.md`: istruzioni rapide.

Uso:

```bash
chmod +x setup-cnpe-examlike.sh
./setup-cnpe-examlike.sh
less ~/course/cnpe-examlike/domande-cnpe-examlike.md
```

Cleanup:

```bash
./setup-cnpe-examlike.sh --cleanup
```

Differenza rispetto al lab caricato:
- il lab originale è molto focalizzato su Gatekeeper;
- questo introduce troubleshooting platform, GitOps/Kustomize, Rollouts, CRD self-service, RBAC, storage e observability.
