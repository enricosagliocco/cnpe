# CNPE Specifici - Lacune Mirate - Platform APIs e Self-Service - Domande
> Killer Shell style | Kubernetes 1.35 | Focus: API platform, claims, golden path

---

## Indice delle Domande

| Q 1 | Namespace self-service template |
| Q 2 | ResourceQuota e LimitRange default |
| Q 3 | Developer RBAC bundle |
| Q 4 | Catalog API via CRD |
| Q 5 | Claim to managed resource |
| Q 6 | Crossplane Composition base |
| Q 7 | Tenant isolation controls |
| Q 8 | Golden path app bootstrap |
| Q 9 | Service request workflow |
| Q10 | API versioning e backward compatibility |
| Q11 | Troubleshooting claim non pronta |
| Q12 | Report di adozione piattaforma |

---

## Question 1 | Namespace self-service template

> Instance: `ssh cnpe-pa01`

1. Crea manifest template namespace team-a con label owner=team-a.
2. Aggiungi annotation purpose=self-service.
3. Applica e salva output in /course/1/pa01-namespace.txt.

---

## Question 2 | ResourceQuota e LimitRange default

> Instance: `ssh cnpe-pa02`

Namespace: team-a

1. Definisci ResourceQuota requests.cpu=2, requests.memory=4Gi, pods=20.
2. Definisci LimitRange default cpu=250m, memory=256Mi.
3. Verifica applicazione policy.
4. Salva output in /course/2/pa02-quota-limits.txt.

---

## Question 3 | Developer RBAC bundle

> Instance: `ssh cnpe-pa03`

Namespace: team-a

1. Crea serviceaccount dev-user.
2. Concedi create/get/list/watch su deploy, svc, configmap.
3. Verifica che non possa creare rolebinding.
4. Salva evidenza in /course/3/pa03-rbac.txt.

---

## Question 4 | Catalog API via CRD

> Instance: `ssh cnpe-pa04`

1. Crea CRD PlatformService con campi spec.tier, spec.owner, spec.runtime.
2. Crea una risorsa PlatformService chiamata orders-api.
3. Verifica get/describe.
4. Salva manifest in /course/4/pa04-platformservice.yaml.

---

## Question 5 | Claim to managed resource

> Instance: `ssh cnpe-pa05`

1. Definisci una claim DbClaim con parametri size e engine.
2. Crea claim orders-db in namespace team-a.
3. Verifica stato claim.
4. Salva output in /course/5/pa05-dbclaim.txt.

---

## Question 6 | Crossplane Composition base

> Instance: `ssh cnpe-pa06`

1. Crea XRD minimale per XTeamDatabase.
2. Crea Composition che materializzi almeno un ConfigMap placeholder.
3. Collega claim al composite.
4. Salva manifest in /course/6/pa06-composition.yaml.

---

## Question 7 | Tenant isolation controls

> Instance: `ssh cnpe-pa07`

1. Implementa NetworkPolicy per isolamento namespace team-a.
2. Applica policy per impedire accesso cross-namespace non autorizzato.
3. Verifica con pod client in namespace diverso.
4. Salva output in /course/7/pa07-isolation.txt.

---

## Question 8 | Golden path app bootstrap

> Instance: `ssh cnpe-pa08`

1. Crea bundle YAML riusabile con Deployment, Service, HPA, PDB.
2. Parametrizza nome app tramite kustomize/vars.
3. Applica bundle per app payments.
4. Salva render finale in /course/8/pa08-golden-path.yaml.

---

## Question 9 | Service request workflow

> Instance: `ssh cnpe-pa09`

1. Definisci API custom TeamRequest con spec.type e spec.sla.
2. Crea TeamRequest per richiesta cache redis.
3. Implementa status initiale Submitted.
4. Salva output in /course/9/pa09-teamrequest.txt.

---

## Question 10 | API versioning e backward compatibility

> Instance: `ssh cnpe-pa10`

1. Estendi CRD PlatformService con versione v1beta1.
2. Mantieni v1alpha1 served e imposta v1beta1 storage.
3. Verifica lettura di vecchie risorse.
4. Salva evidenze in /course/10/pa10-versioning.txt.

---

## Question 11 | Troubleshooting claim non pronta

> Instance: `ssh cnpe-pa11`

1. Diagnostica claim orders-db bloccata in Pending/NotReady.
2. Correggi Composition o claim con fix minimo.
3. Verifica Ready=True.
4. Scrivi root cause in /course/11/pa11-troubleshooting.md.

---

## Question 12 | Report di adozione piattaforma

> Instance: `ssh cnpe-pa12`

1. Esporta elenco API custom e claims create.
2. Esporta stato namespace team e workload bootstrap.
3. Salva report in /course/12/pa12-platform-report.txt.
