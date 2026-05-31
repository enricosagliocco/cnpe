# CNPE Specifici - Batteria Bilanciata 03 - Domande
> Killer Shell style | 15 quesiti bilanciati: GitOps/CD, Security/Policy, Platform APIs

---

## Indice delle Domande

| Q 1 | Argo CD bootstrap da repo locale |
| Q 2 | Automated sync hardening |
| Q 3 | Progressive delivery via Git |
| Q 4 | Flux drift recovery |
| Q 5 | Git workflow promotion |
| Q 6 | PSS admission test |
| Q 7 | RBAC service account scope |
| Q 8 | Kyverno mutate+validate |
| Q 9 | Gatekeeper deny non-compliant |
| Q10 | NetworkPolicy cross-namespace block |
| Q11 | Tenant namespace provisioning |
| Q12 | Self-service quota template |
| Q13 | Custom API TeamRequest |
| Q14 | Composition readiness debugging |
| Q15 | Report finale readiness retake |

---

## Question 1 | Argo CD bootstrap da repo locale
> Instance: ssh cnpe-b0301
1. Crea Application app-b03 da /course/1/repo-gitops.
2. Verifica stato e salva in /course/1/b03-q01.txt.

## Question 2 | Automated sync hardening
> Instance: ssh cnpe-b0302
1. Abilita automated, prune, selfHeal.
2. Salva stato in /course/2/b03-q02.txt.

## Question 3 | Progressive delivery via Git
> Instance: ssh cnpe-b0303
1. Versiona un Rollout canary nel repo GitOps.
2. Aggiorna immagine via commit.
3. Salva evidenza in /course/3/b03-q03.txt.

## Question 4 | Flux drift recovery
> Instance: ssh cnpe-b0304
1. Crea source + kustomization Flux.
2. Simula drift e verifica recovery.
3. Salva output in /course/4/b03-q04.txt.

## Question 5 | Git workflow promotion
> Instance: ssh cnpe-b0305
1. Esegui promotion dev->stage con commit tracciabile.
2. Salva log in /course/5/b03-q05.txt.

## Question 6 | PSS admission test
> Instance: ssh cnpe-b0306
1. Applica restricted su ns-b03-sec.
2. Testa pod non conforme.
3. Salva output in /course/6/b03-q06.txt.

## Question 7 | RBAC service account scope
> Instance: ssh cnpe-b0307
1. Crea SA + ruolo minimo su workload.
2. Verifica accessi consentiti/negati.
3. Salva output in /course/7/b03-q07.txt.

## Question 8 | Kyverno mutate+validate
> Instance: ssh cnpe-b0308
1. Crea una policy mutate (es. aggiunta label default).
2. Crea validate policy (deny latest).
3. Salva output in /course/8/b03-q08.txt.

## Question 9 | Gatekeeper deny non-compliant
> Instance: ssh cnpe-b0309
1. Definisci vincolo per risorse cpu/memory requests.
2. Verifica deny su manifest non conforme.
3. Salva output in /course/9/b03-q09.txt.

## Question 10 | NetworkPolicy cross-namespace block
> Instance: ssh cnpe-b0310
1. Blocca traffico cross-namespace non autorizzato.
2. Verifica con pod test.
3. Salva output in /course/10/b03-q10.txt.

## Question 11 | Tenant namespace provisioning
> Instance: ssh cnpe-b0311
1. Crea namespace team-b03 con label/annotation standard.
2. Salva output in /course/11/b03-q11.txt.

## Question 12 | Self-service quota template
> Instance: ssh cnpe-b0312
1. Applica quota + limitrange standard tenant.
2. Salva output in /course/12/b03-q12.txt.

## Question 13 | Custom API TeamRequest
> Instance: ssh cnpe-b0313
1. Crea CRD TeamRequest.
2. Crea risorsa cache-request.
3. Salva manifest in /course/13/b03-q13.yaml.

## Question 14 | Composition readiness debugging
> Instance: ssh cnpe-b0314
1. Diagnostica composite/claim non ready.
2. Applica fix minimo.
3. Salva root cause in /course/14/b03-q14.md.

## Question 15 | Report finale readiness retake
> Instance: ssh cnpe-b0315
1. Esporta summary completo delle 3 aree.
2. Salva report in /course/15/b03-q15-report.txt.
