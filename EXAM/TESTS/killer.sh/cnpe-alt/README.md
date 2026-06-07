# CNPE Alternative Simulator

This is a second CNPE-focused simulator based on the previous Minikube/Gitea package.

Unlike a free-form sandbox, every question names the existing resource, starter
file, required values and verification result. The setup deliberately creates
the incomplete or broken state described by each exercise.

## Run

```bash
export GITEA_URL="http://192.168.1.56:3000/"
export GITEA_TOKEN="d2fcd54b7a8e2762920d929bfd4456db208659e4"
export GITEA_USER="cnpe-user"
export GITEA_PASS="cnpe-pass"
export GITEA_ORG="organization"

chmod +x *.sh
./setup-cnpe-alt-lab.sh
```

The lab files are created under `~/course-alt` by default.

## Files

- `setup-cnpe-alt-lab.sh`: entrypoint. Runs the base setup and then creates the alternative scenario overlay.
- `cnpe-setup-part1.sh`, `cnpe-setup-part2.sh`, `cnpe-setup-part3.sh`: reused base setup scripts.
- `domande-alt.md`: 20 alternative CNPE-style questions.
- `wipe_gitea_repos_orgs.sh`: optional cleanup utility.

## GUI

`domande-alt.md` contiene una tabella con URL, port-forward e credenziali per
Prometheus, Argo CD, OpenCost, Grafana, Argo Workflows, Tekton, Jaeger e Argo
Rollouts. Per le risorse Kubernetes senza dashboard nativa usa Lens/OpenLens
con il kubeconfig corrente.
