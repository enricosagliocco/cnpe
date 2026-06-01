# CNPE Specifici - Batteria Bilanciata 01 - Domande
> Killer Shell style | 15 quesiti bilanciati: GitOps/CD, Security/Policy, Platform APIs

---

> Git remoto (Gitea): usare i repository remoti creati dal setup.

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
mkdir -p /course/1 /course/4
rm -rf /course/1/repo-gitops /course/4/repo-flux
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-bilanciata-01-repo-gitops.git" /course/1/repo-gitops
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-bilanciata-01-repo-flux.git" /course/4/repo-flux
```

## Indice delle Domande

| Q 1 | Argo CD application bootstrap |
| Q 2 | Drift e self-heal |
| Q 3 | Sync policy prune |
| Q 4 | Flux GitRepository + Kustomization |
| Q 5 | Promotion tramite Git |
| Q 6 | Pod Security restricted |
| Q 7 | RBAC least privilege |
| Q 8 | Kyverno require labels |
| Q 9 | Gatekeeper requests limits |
| Q10 | NetworkPolicy tenant isolation |
| Q11 | Namespace self-service |
| Q12 | ResourceQuota e LimitRange |
| Q13 | CRD PlatformService |
| Q14 | Claim e Composition base |
| Q15 | Report finale platform compliance |

---

## Question 1 | Argo CD application bootstrap

> Instance: ssh cnpe-b0101

1. Crea Application app-b01 che punti al repo Gitea clonato in /course/1/repo-gitops (path manifests/base, branch main).
2. Abilita CreateNamespace.
3. Verifica stato Synced/Healthy.
4. Salva evidenza in /course/1/b01-q01.txt.

## Question 2 | Drift e self-heal

> Instance: ssh cnpe-b0102

1. Modifica manualmente replicas del deployment gestito da app-b01.
2. Abilita selfHeal nell Application.
3. Verifica riconciliazione.
4. Salva output in /course/2/b01-q02.txt.

## Question 3 | Sync policy prune

> Instance: ssh cnpe-b0103

1. Abilita automated + prune su app-b01.
2. Rimuovi una risorsa dal repo.
3. Verifica prune lato cluster.
4. Salva output in /course/3/b01-q03.txt.

## Question 4 | Flux GitRepository + Kustomization

> Instance: ssh cnpe-b0104

1. Crea GitRepository puntando a /course/4/repo-flux.
2. Crea Kustomization su overlays/dev.
3. Verifica Ready=True.
4. Salva output in /course/4/b01-q04.txt.

## Question 5 | Promotion tramite Git

> Instance: ssh cnpe-b0105

1. Aggiorna immagine in branch dev.
2. Promuovi in stage con merge/cherry-pick minimo.
3. Verifica sync in stage.
4. Salva log git + stato app in /course/5/b01-q05.txt.

## Question 6 | Pod Security restricted

> Instance: ssh cnpe-b0106

1. Etichetta ns-b01-sec con enforce restricted latest.
2. Testa pod non conforme.
3. Salva evidenza in /course/6/b01-q06.txt.

## Question 7 | RBAC least privilege

> Instance: ssh cnpe-b0107

1. Crea SA auditor in ns-b01-sec.
2. Concedi solo get/list pods.
3. Verifica impossibilita delete pods.
4. Salva output in /course/7/b01-q07.txt.

## Question 8 | Kyverno require labels

> Instance: ssh cnpe-b0108

1. Crea policy che richiede label owner e env sui Pod.
2. Verifica deny su pod non conforme.
3. Salva output in /course/8/b01-q08.txt.

## Question 9 | Gatekeeper requests limits

> Instance: ssh cnpe-b0109

1. Crea ConstraintTemplate per requests cpu/memory obbligatorie.
2. Applica Constraint su ns-b01-sec.
3. Verifica deny workload senza requests.
4. Salva output in /course/9/b01-q09.txt.

## Question 10 | NetworkPolicy tenant isolation

> Instance: ssh cnpe-b0110

1. Applica default deny su ns-b01-team.
2. Consenti solo traffico intra-namespace tcp/80.
3. Salva verifica in /course/10/b01-q10.txt.

## Question 11 | Namespace self-service

> Instance: ssh cnpe-b0111

1. Crea namespace team-b01 con label owner=team-b01 e annotation purpose=self-service.
2. Salva manifest e get output in /course/11/b01-q11.txt.

## Question 12 | ResourceQuota e LimitRange

> Instance: ssh cnpe-b0112

1. Applica quota requests.cpu=2 requests.memory=4Gi pods=20 su team-b01.
2. Applica limiti default cpu=250m memory=256Mi.
3. Salva output in /course/12/b01-q12.txt.

## Question 13 | CRD PlatformService

> Instance: ssh cnpe-b0113

1. Crea CRD PlatformService con campi spec.owner spec.tier spec.runtime.
2. Crea risorsa orders-api in team-b01.
3. Salva manifest in /course/13/b01-q13.yaml.

## Question 14 | Claim e Composition base

> Instance: ssh cnpe-b0114

1. Crea XRD + Composition minima per XTeamDatabase.
2. Crea claim orders-db in team-b01.
3. Salva output in /course/14/b01-q14.txt.

## Question 15 | Report finale platform compliance

> Instance: ssh cnpe-b0115

1. Esporta app GitOps, policy e risorse platform create.
2. Salva report in /course/15/b01-q15-report.txt.
