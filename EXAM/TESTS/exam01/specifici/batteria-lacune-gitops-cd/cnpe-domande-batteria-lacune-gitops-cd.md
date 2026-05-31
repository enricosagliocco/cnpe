# CNPE Specifici - Lacune Mirate - GitOps e Continuous Delivery - Domande
> Killer Shell style | Kubernetes 1.35 | Focus: Argo CD, Flux, progressive delivery

---

## Indice delle Domande

| Q 1 | Argo CD install e stato |
| Q 2 | App da repo Git (branch main) |
| Q 3 | Drift detection e self-heal |
| Q 4 | Sync policy automated + prune |
| Q 5 | Flux source + kustomization |
| Q 6 | HelmRelease con rollback |
| Q 7 | Multi-env overlays con Kustomize |
| Q 8 | Promotion dev -> stage via Git |
| Q 9 | Sync waves e dipendenze |
| Q10 | Argo Rollouts gating in GitOps |
| Q11 | Troubleshooting app OutOfSync |
| Q12 | Evidenze e report finale |

---

## Question 1 | Argo CD install e stato

> Instance: `ssh cnpe-gc01`

1. Verifica che namespace argocd e deployment controller/server siano Ready.
2. Verifica che il service account di argocd-application-controller esista.
3. Salva output in /course/1/gc01-argocd-check.txt.

---

## Question 2 | App da repo Git (branch main)

> Instance: `ssh cnpe-gc02`

Repo locale: /course/2/repo-gitops
Namespace target: ns-gc-app

1. Crea Application Argo CD app-gc02 puntando a manifests/base su branch main.
2. Abilita namespace auto-create.
3. Verifica stato Synced/Healthy.
4. Salva manifest app in /course/2/app-gc02.yaml.

---

## Question 3 | Drift detection e self-heal

> Instance: `ssh cnpe-gc03`

Application: app-gc02

1. Esegui una modifica manuale del Deployment live (replicas=5).
2. Configura self-heal automatico nell Application.
3. Verifica ripristino allo stato Git.
4. Salva evidenza in /course/3/gc03-selfheal.txt.

---

## Question 4 | Sync policy automated + prune

> Instance: `ssh cnpe-gc04`

1. Configura l Application con syncPolicy automated.
2. Abilita prune e allowEmpty.
3. Rimuovi una risorsa dal repository e verifica prune in cluster.
4. Salva log comandi in /course/4/gc04-prune.txt.

---

## Question 5 | Flux source + kustomization

> Instance: `ssh cnpe-gc05`

Repo locale: /course/5/repo-flux
Namespace target: flux-system

1. Crea una GitRepository Flux che punti al repo locale.
2. Crea una Kustomization che applichi overlays/dev.
3. Verifica Ready condition.
4. Salva output in /course/5/gc05-flux-ready.txt.

---

## Question 6 | HelmRelease con rollback

> Instance: `ssh cnpe-gc06`

1. Definisci HelmRepository e HelmRelease per nginx.
2. Esegui un update con valore invalido e osserva failure.
3. Ripristina con rollback/upgrade corretto.
4. Salva report in /course/6/gc06-helmrelease.txt.

---

## Question 7 | Multi-env overlays con Kustomize

> Instance: `ssh cnpe-gc07`

Repo locale: /course/7/repo-kustomize

1. Crea overlay dev e stage con diversa replica count.
2. Verifica render di entrambe con kubectl kustomize.
3. Applica solo stage e conferma namespace corretto.
4. Salva render in /course/7/gc07-render-stage.yaml.

---

## Question 8 | Promotion dev -> stage via Git

> Instance: `ssh cnpe-gc08`

1. In dev aggiorna immagine app a versione v2.
2. Commit su branch dev.
3. Promuovi in stage via cherry-pick o merge minimale.
4. Verifica che Argo CD sincronizzi stage.
5. Salva evidenze git + sync in /course/8/gc08-promotion.txt.

---

## Question 9 | Sync waves e dipendenze

> Instance: `ssh cnpe-gc09`

1. Configura sync-wave: ConfigMap in wave 0, Deployment in wave 1.
2. Applica tramite Argo CD.
3. Verifica ordine applicazione negli eventi.
4. Salva output in /course/9/gc09-sync-wave.txt.

---

## Question 10 | Argo Rollouts gating in GitOps

> Instance: `ssh cnpe-gc10`

1. Versiona un Rollout canary in repo GitOps.
2. Applica update immagine da Git (non con set image diretto).
3. Verifica che il rollout avanzi a step con pause.
4. Salva evidenza in /course/10/gc10-rollout-gitops.txt.

---

## Question 11 | Troubleshooting app OutOfSync

> Instance: `ssh cnpe-gc11`

1. Identifica causa OutOfSync di app-gc11.
2. Risolvi con la modifica minima lato Git.
3. Verifica ritorno a Synced/Healthy.
4. Scrivi root cause + fix in /course/11/gc11-troubleshooting.md.

---

## Question 12 | Evidenze e report finale

> Instance: `ssh cnpe-gc12`

1. Esporta elenco Application Argo CD e Kustomization Flux.
2. Esporta stato dei workload gestiti dal GitOps.
3. Salva report finale in /course/12/gc12-final-report.txt.
