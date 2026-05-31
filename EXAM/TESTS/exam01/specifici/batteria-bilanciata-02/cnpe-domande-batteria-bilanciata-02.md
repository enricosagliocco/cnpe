# CNPE Specifici - Batteria Bilanciata 02 - Domande
> Killer Shell style | 15 quesiti bilanciati: GitOps/CD, Security/Policy, Platform APIs

---

## Indice delle Domande

| Q 1 | Argo CD app multi-namespace |
| Q 2 | OutOfSync troubleshooting |
| Q 3 | Sync windows e policy |
| Q 4 | Flux reconcile manuale |
| Q 5 | HelmRelease GitOps fix |
| Q 6 | PSS restricted con eccezione minima |
| Q 7 | RBAC read-only team |
| Q 8 | Kyverno deny latest |
| Q 9 | Gatekeeper required labels |
| Q10 | NetworkPolicy egress control |
| Q11 | Self-service namespace onboarding |
| Q12 | Quota per tenant |
| Q13 | API PlatformService v1alpha1 |
| Q14 | API versioning v1beta1 storage |
| Q15 | Report finale bilanciato |

---

## Question 1 | Argo CD app multi-namespace
> Instance: ssh cnpe-b0201
1. Crea Application app-b02 da /course/1/repo-gitops.
2. Destination namespace ns-b02-app.
3. Verifica Synced/Healthy e salva in /course/1/b02-q01.txt.

## Question 2 | OutOfSync troubleshooting
> Instance: ssh cnpe-b0202
1. Causa OutOfSync con modifica live.
2. Ripristina via Git.
3. Salva root cause in /course/2/b02-q02.md.

## Question 3 | Sync windows e policy
> Instance: ssh cnpe-b0203
1. Definisci sync policy automatica con prune.
2. Verifica applicazione policy.
3. Salva output in /course/3/b02-q03.txt.

## Question 4 | Flux reconcile manuale
> Instance: ssh cnpe-b0204
1. Crea GitRepository e Kustomization.
2. Forza reconcile manuale.
3. Salva output in /course/4/b02-q04.txt.

## Question 5 | HelmRelease GitOps fix
> Instance: ssh cnpe-b0205
1. Applica HelmRelease con valore errato.
2. Correggi via Git e verifica recovery.
3. Salva output in /course/5/b02-q05.txt.

## Question 6 | PSS restricted con eccezione minima
> Instance: ssh cnpe-b0206
1. Applica restricted a ns-b02-sec.
2. Definisci eccezione solo dove strettamente necessaria.
3. Salva evidenza in /course/6/b02-q06.txt.

## Question 7 | RBAC read-only team
> Instance: ssh cnpe-b0207
1. Crea ruolo read-only workload.
2. Associa a SA team-reader.
3. Verifica can-i e salva in /course/7/b02-q07.txt.

## Question 8 | Kyverno deny latest
> Instance: ssh cnpe-b0208
1. Crea policy deny latest.
2. Testa deny e pass con tag pinning.
3. Salva output in /course/8/b02-q08.txt.

## Question 9 | Gatekeeper required labels
> Instance: ssh cnpe-b0209
1. Impone label owner e cost-center.
2. Verifica deny su risorsa non conforme.
3. Salva output in /course/9/b02-q09.txt.

## Question 10 | NetworkPolicy egress control
> Instance: ssh cnpe-b0210
1. Definisci default deny egress in ns-b02-team.
2. Consenti solo DNS + api interno.
3. Salva output in /course/10/b02-q10.txt.

## Question 11 | Self-service namespace onboarding
> Instance: ssh cnpe-b0211
1. Crea ns team-b02 con label standard.
2. Aggiungi quota baseline.
3. Salva output in /course/11/b02-q11.txt.

## Question 12 | Quota per tenant
> Instance: ssh cnpe-b0212
1. Aggiorna quota tenant con requests/limits.
2. Verifica enforcement.
3. Salva output in /course/12/b02-q12.txt.

## Question 13 | API PlatformService v1alpha1
> Instance: ssh cnpe-b0213
1. Crea CRD PlatformService.
2. Crea risorsa billing-api.
3. Salva manifest in /course/13/b02-q13.yaml.

## Question 14 | API versioning v1beta1 storage
> Instance: ssh cnpe-b0214
1. Aggiungi v1beta1.
2. Mantieni v1alpha1 served.
3. Salva verifica in /course/14/b02-q14.txt.

## Question 15 | Report finale bilanciato
> Instance: ssh cnpe-b0215
1. Esporta stato GitOps, policy e API platform.
2. Salva report in /course/15/b02-q15-report.txt.
