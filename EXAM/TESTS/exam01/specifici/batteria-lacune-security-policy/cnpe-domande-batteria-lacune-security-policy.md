# CNPE Specifici - Lacune Mirate - Security e Policy Enforcement - Domande
> Killer Shell style | Kubernetes 1.35 | Focus: PSS, RBAC, Kyverno, Gatekeeper

---

## Indice delle Domande

| Q 1 | Pod Security Standards restricted |
| Q 2 | RBAC least privilege |
| Q 3 | ServiceAccount hardening |
| Q 4 | Kyverno require labels |
| Q 5 | Kyverno deny latest tag |
| Q 6 | Gatekeeper ConstraintTemplate |
| Q 7 | NetworkPolicy default deny |
| Q 8 | Secret management e rotazione |
| Q 9 | Image provenance e firma |
| Q10 | Policy exceptions controllate |
| Q11 | Troubleshooting denied workload |
| Q12 | Report compliance finale |

---

## Question 1 | Pod Security Standards restricted

> Instance: `ssh cnpe-sp01`

Namespace: ns-sp01

1. Applica label namespace per enforce restricted latest.
2. Verifica che un pod privilegiato venga bloccato.
3. Salva evidenza in /course/1/sp01-pss.txt.

---

## Question 2 | RBAC least privilege

> Instance: `ssh cnpe-sp02`

Namespace: ns-sp02

1. Crea Role che permetta solo get,list pods.
2. Associa RoleBinding a serviceaccount auditor.
3. Verifica con kubectl auth can-i.
4. Salva output in /course/2/sp02-rbac.txt.

---

## Question 3 | ServiceAccount hardening

> Instance: `ssh cnpe-sp03`

Namespace: ns-sp03

1. Crea SA runner con automountServiceAccountToken=false.
2. Associa il SA a un Deployment.
3. Verifica assenza token mountato nel pod.
4. Salva evidenza in /course/3/sp03-sa-hardening.txt.

---

## Question 4 | Kyverno require labels

> Instance: `ssh cnpe-sp04`

1. Crea ClusterPolicy che richieda label owner e env sui Pod.
2. Testa una creazione Pod non conforme (deve fallire).
3. Testa Pod conforme (deve passare).
4. Salva manifest e test output in /course/4/sp04-kyverno-labels.txt.

---

## Question 5 | Kyverno deny latest tag

> Instance: `ssh cnpe-sp05`

1. Crea policy che neghi immagini con tag latest.
2. Applica Deployment con latest e verifica deny.
3. Correggi immagine pinning a tag/versione e verifica pass.
4. Salva output in /course/5/sp05-deny-latest.txt.

---

## Question 6 | Gatekeeper ConstraintTemplate

> Instance: `ssh cnpe-sp06`

1. Crea ConstraintTemplate per imporre requests.cpu e requests.memory.
2. Crea Constraint scoped al namespace ns-sp06.
3. Verifica deny su Pod senza requests.
4. Salva evidenze in /course/6/sp06-gatekeeper.txt.

---

## Question 7 | NetworkPolicy default deny

> Instance: `ssh cnpe-sp07`

Namespace: ns-sp07

1. Applica default deny ingress+egress.
2. Consenti solo traffico intra-namespace su porta 80.
3. Verifica comportamento con pod di test.
4. Salva risultato in /course/7/sp07-networkpolicy.txt.

---

## Question 8 | Secret management e rotazione

> Instance: `ssh cnpe-sp08`

Namespace: ns-sp08

1. Crea secret generic app-credentials da valori file.
2. Monta il secret in Deployment api.
3. Ruota la chiave e forza restart controllato workload.
4. Salva evidenze in /course/8/sp08-secret-rotation.txt.

---

## Question 9 | Image provenance e firma

> Instance: `ssh cnpe-sp09`

1. Verifica presenza di policy verifyImages (Kyverno/Cosign) nel cluster.
2. Applica workload con immagine non firmata e registra risultato.
3. Applica workload firmata consentita (se disponibile nel lab).
4. Salva output in /course/9/sp09-provenance.txt.

---

## Question 10 | Policy exceptions controllate

> Instance: `ssh cnpe-sp10`

1. Definisci eccezione temporanea solo per namespace ns-sp10.
2. Applica eccezione con scope minimo e durata documentata.
3. Verifica che altri namespace restino bloccati.
4. Salva evidenze in /course/10/sp10-exception.txt.

---

## Question 11 | Troubleshooting denied workload

> Instance: `ssh cnpe-sp11`

1. Identifica perche deployment app-sp11 e denied.
2. Applica fix minimo al manifest (non disabilitare policy globali).
3. Verifica deploy Running.
4. Scrivi root cause e fix in /course/11/sp11-troubleshooting.md.

---

## Question 12 | Report compliance finale

> Instance: `ssh cnpe-sp12`

1. Esporta elenco policy attive e violation correnti.
2. Esporta stato workload dei namespace sp.
3. Salva report in /course/12/sp12-compliance-report.txt.
