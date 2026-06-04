# CNPE Exam-like Lab 2 — batteria domande

Setup: \`~/course/cnpe-gitea-lab\`  
Gitea: \`http://192.168.1.56:3000/\`  
Org: \`organization\`  
Repo: team-monitoring, web-client, platform-apps, pipeline-tasks, policy-manifests.

Tempo consigliato: 120 minuti. Modifica il minimo necessario, verifica e salva output richiesti.

## Q1 — CRD, Kustomize, Git
Repo: \`~/course/cnpe-gitea-lab/work/team-monitoring\`.
1. Aggiungi versione \`v1alpha2\` al CRD \`TeamMonitoring\`.
2. In \`v1alpha2\`, \`spec.target\` deve diventare object con stringhe \`namespace\` e \`service\`.
3. \`v1alpha1\` deve restare served ma non storage; \`v1alpha2\` deve essere storage.
4. Applica con \`kubectl apply -k .\` e committa su main.
5. Crea \`TeamMonitoring/general\` in namespace \`pacific\` con target \`test-ns/test-svc\`.

## Q2 — Argo CD GitOps update
Applicazione Argo CD: \`web-client\`. Repo: \`~/course/cnpe-gitea-lab/work/web-client\`.
1. Porta la label pod \`version\` a \`v2\`.
2. Cambia la risposta Nginx in \`Lagoon Web Client v2\`.
3. Commit e push su main.
4. Sincronizza Argo CD e verifica pod e risposta HTTP.

## Q3 — Branch e nuova Argo Application
1. Nel repo \`web-client\`, crea branch \`testing\`.
2. Porta label \`version\` a \`v3\` e risposta a \`Lagoon Web Client v3\`.
3. Push del branch.
4. Crea Application \`web-client-testing\` in \`argocd\`, branch \`testing\`, path \`manifests\`, namespace destinazione \`lagoon-testing\`.
5. Verifica che \`web-client\` resti v2 in \`lagoon\` e testing sia v3 in \`lagoon-testing\`.

## Q4 — ApplicationSet troubleshooting
Repo: \`platform-apps\`. ApplicationSet: \`platform-apps\`.
1. Correggi la destinazione generata: le app devono andare in \`platform-dev\`, non \`platform-prod\`.
2. Commit e push.
3. Applica/aggiorna ApplicationSet.
4. Verifica che \`api-dev\` e \`worker-dev\` siano Synced/Healthy e che i pod siano in \`platform-dev\`.

## Q5 — Prometheus scrape config
Namespace: \`prometheus\`; workload metrics: \`kariba\`.
1. Estendi la ConfigMap \`prometheus-server\` affinché lo scrape job \`minimal\` includa anche pod \`app=proxy\`.
2. Fai reload/restart di Prometheus.
3. Esegui query PromQL: \`sum by (deployment) (http_requests_per_minute{})\`.
4. Scala a 2 repliche il Deployment con valore più alto.
5. Salva query e risultato in \`~/course/cnpe-gitea-lab/answers/q5-prometheus.txt\`.

## Q6 — Flagger blue/green app1
Namespace: \`malawi\`.
1. Aumenta di 1 la patch version di \`APP_VERSION\` per \`deploy/app1\`.
2. Attendi promozione Flagger.
3. Salva gli eventi rilevanti della Canary in \`~/course/cnpe-gitea-lab/answers/q6-app1-events.log\`.

## Q7 — Flagger pre-rollout webhook app2
1. Aggiorna \`canary/app2\` aggiungendo webhook \`pre-rollout\` che faccia HTTP GET su \`http://app2-canary.malawi\` e si aspetti 200.
2. Triggera rollout impostando \`APP_VERSION=1.0.1\`.
3. Verifica promozione e salva \`kubectl -n malawi describe canary app2\` in \`~/course/cnpe-gitea-lab/answers/q7-app2.txt\`.

## Q8 — Tekton onboarding parallelo
Repo: \`pipeline-tasks\`, path \`p1-team-onboarding\`.
1. Aggiungi Task \`p1-create-labels\` che aggiunga label \`auto-created=true\` al namespace creato.
2. Deve partire dopo \`p1-create-namespace\` e in parallelo con \`p1-create-roles\`.
3. Applica e lancia PipelineRun per team \`butter\` e \`croissant\`.
4. Verifica namespace, label e role.

## Q9 — Tekton scanner
1. Applica risorse da \`p2-team-scanner\`.
2. Lancia Pipeline \`p2-team-scanner\` con \`target_namespace=kariba\`, \`forbidden1=miner\`, \`forbidden2=torrent\`.
3. Salva log in \`~/course/cnpe-gitea-lab/answers/q9-p2.log\`.

## Q10 — Security hardening e immagine esplicita
Repo: \`policy-manifests\`.
1. Correggi immagine \`payment-api\`: non deve usare tag implicito latest.
2. Aggiungi securityContext pod/container con \`runAsNonRoot\`, \`allowPrivilegeEscalation=false\`, \`readOnlyRootFilesystem=true\` dove compatibile.
3. Applica con Kustomize, commit e push.
4. Verifica rollout.

## Q11 — NetworkPolicy minima
Namespace \`security-lab\`.
1. Crea NetworkPolicy che consenta ingress a \`payment-api\` solo da pod con label \`access=allowed\` sulla porta 80.
2. Salva il manifest in repo \`policy-manifests\` e committa.
3. Applica e verifica che la policy esista.

## Q12 — Report finale
Crea \`~/course/cnpe-gitea-lab/answers/final-report.txt\` con:
1. output \`kubectl get applications -A\`
2. output \`kubectl -n kariba get deploy\`
3. output \`kubectl -n malawi get canary\`
4. output \`kubectl get teammonitoring -A\`
5. lista commit Git dei repo modificati.