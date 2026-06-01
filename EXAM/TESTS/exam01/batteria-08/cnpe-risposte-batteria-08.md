# CNPE Simulator - Batteria 08 - Risposte Guida
> Observability, SLO e Incident Response
> Focus strumenti: Prometheus, Alertmanager, Grafana, Loki, Jaeger

---

## Bootstrap Git da Gitea

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
for q in 1 3 5 9 10 11 17 19; do
  mkdir -p /course/${q}
  rm -rf /course/${q}/repo-b08
  git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-b08-q${q}.git" "/course/${q}/repo-b08"
done
```

## Strategia consigliata
1. Leggi i manifest e identifica il delta minimo.
2. Applica prima in dry-run server-side quando possibile.
3. Esegui verifica tecnica e raccogli evidenze su file.
4. Mantieni pulizia risorse fallite (Workflow/PipelineRun/Rollout).

---

## Question 1 - Guida rapida

1. Identifica la risorsa core del task (Deployment, Policy, Route, CRD, Pipeline).
2. Applica patch/manifests con kubectl/CLI specializzato del dominio.
3. Verifica con get/describe/logs/events e stato controller.
4. Scrivi output finale in /course/1/b08-q1.txt.

Comandi tipici:
- kubectl get all -n <namespace>
- kubectl describe <resource>
- kubectl get events --sort-by=.lastTimestamp

---

## Question 2 - Guida rapida

1. Identifica la risorsa core del task (Deployment, Policy, Route, CRD, Pipeline).
2. Applica patch/manifests con kubectl/CLI specializzato del dominio.
3. Verifica con get/describe/logs/events e stato controller.
4. Scrivi output finale in /course/2/b08-q2.txt.

Comandi tipici:
- kubectl get all -n <namespace>
- kubectl describe <resource>
- kubectl get events --sort-by=.lastTimestamp

---

## Question 3 - Guida rapida

1. Identifica la risorsa core del task (Deployment, Policy, Route, CRD, Pipeline).
2. Applica patch/manifests con kubectl/CLI specializzato del dominio.
3. Verifica con get/describe/logs/events e stato controller.
4. Scrivi output finale in /course/3/b08-q3.txt.

Comandi tipici:
- kubectl get all -n <namespace>
- kubectl describe <resource>
- kubectl get events --sort-by=.lastTimestamp

---

## Question 4 - Guida rapida

1. Identifica la risorsa core del task (Deployment, Policy, Route, CRD, Pipeline).
2. Applica patch/manifests con kubectl/CLI specializzato del dominio.
3. Verifica con get/describe/logs/events e stato controller.
4. Scrivi output finale in /course/4/b08-q4.txt.

Comandi tipici:
- kubectl get all -n <namespace>
- kubectl describe <resource>
- kubectl get events --sort-by=.lastTimestamp

---

## Question 5 - Guida rapida

1. Identifica la risorsa core del task (Deployment, Policy, Route, CRD, Pipeline).
2. Applica patch/manifests con kubectl/CLI specializzato del dominio.
3. Verifica con get/describe/logs/events e stato controller.
4. Scrivi output finale in /course/5/b08-q5.txt.

Comandi tipici:
- kubectl get all -n <namespace>
- kubectl describe <resource>
- kubectl get events --sort-by=.lastTimestamp

---

## Question 6 - Guida rapida

1. Identifica la risorsa core del task (Deployment, Policy, Route, CRD, Pipeline).
2. Applica patch/manifests con kubectl/CLI specializzato del dominio.
3. Verifica con get/describe/logs/events e stato controller.
4. Scrivi output finale in /course/6/b08-q6.txt.

Comandi tipici:
- kubectl get all -n <namespace>
- kubectl describe <resource>
- kubectl get events --sort-by=.lastTimestamp

---

## Question 7 - Guida rapida

1. Identifica la risorsa core del task (Deployment, Policy, Route, CRD, Pipeline).
2. Applica patch/manifests con kubectl/CLI specializzato del dominio.
3. Verifica con get/describe/logs/events e stato controller.
4. Scrivi output finale in /course/7/b08-q7.txt.

Comandi tipici:
- kubectl get all -n <namespace>
- kubectl describe <resource>
- kubectl get events --sort-by=.lastTimestamp

---

## Question 8 - Guida rapida

1. Identifica la risorsa core del task (Deployment, Policy, Route, CRD, Pipeline).
2. Applica patch/manifests con kubectl/CLI specializzato del dominio.
3. Verifica con get/describe/logs/events e stato controller.
4. Scrivi output finale in /course/8/b08-q8.txt.

Comandi tipici:
- kubectl get all -n <namespace>
- kubectl describe <resource>
- kubectl get events --sort-by=.lastTimestamp

---

## Question 9 - Guida rapida

1. Identifica la risorsa core del task (Deployment, Policy, Route, CRD, Pipeline).
2. Applica patch/manifests con kubectl/CLI specializzato del dominio.
3. Verifica con get/describe/logs/events e stato controller.
4. Scrivi output finale in /course/9/b08-q9.txt.

Comandi tipici:
- kubectl get all -n <namespace>
- kubectl describe <resource>
- kubectl get events --sort-by=.lastTimestamp

---

## Question 10 - Guida rapida

1. Identifica la risorsa core del task (Deployment, Policy, Route, CRD, Pipeline).
2. Applica patch/manifests con kubectl/CLI specializzato del dominio.
3. Verifica con get/describe/logs/events e stato controller.
4. Scrivi output finale in /course/10/b08-q10.txt.

Comandi tipici:
- kubectl get all -n <namespace>
- kubectl describe <resource>
- kubectl get events --sort-by=.lastTimestamp

---

