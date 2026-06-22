# Le 20 domande dell'esame — Gatekeeper e Kyverno

Scenario creato da `setup-policy-exam-lab.sh`. I file si trovano in
`~/course-policy-exam`.

**Vincoli:** non disinstallare Kyverno o Gatekeeper; non modificare i loro
Deployment core; conserva i nomi richiesti. Una modifica ai file senza test
reale di admission non completa la domanda.

Per ogni esercizio salva in `evidence.txt` i comandi di verifica e l'output
essenziale. Le domande sono indipendenti: rimuovi le policy `Deny` concluse se
interferiscono con quelle successive.

---

### Q1 – Kyverno security-check senza sovrascrittura

Percorso: `~/course-policy-exam/01`.

Kyverno è installato e la CLI `kyverno` è disponibile.

1. Crea nel Namespace `caribbean` una `NamespacedMutatingPolicy` chiamata
   `security-check`.
2. Muta i Pod durante `CREATE` e `UPDATE`.
3. Aggiungi la label `audit: pending` soltanto se la label `audit` non esiste.
4. Crea i Pod `test-pending` e `test-passed` con immagine `nginx:1-alpine`.
5. Aggiorna `test-passed` a `audit: passed` e dimostra che Kyverno non la
   riporta a `pending`.
6. Verifica la policy anche localmente con la CLI.

Il risultato finale deve mostrare `test-pending=pending` e
`test-passed=passed`.

---

### Q2 – Kyverno default owner condizionale

Percorso: `~/course-policy-exam/02`.

Completa `policy.yaml` per aggiungere l'annotation `owner: platform` ai
ConfigMap in `team-a` solo quando `owner` manca. La policy deve agire su CREATE
e UPDATE. Verifica che `missing.yaml` venga mutato e che `existing.yaml`
mantenga `owner: payments` anche dopo un update della label `version`.

---

### Q3 – Kyverno imagePullPolicy predefinita

Percorso: `~/course-policy-exam/03`.

La `NamespacedMutatingPolicy` `default-pull-policy` deve impostare
`imagePullPolicy: IfNotPresent` su ogni container che non dichiara il campo,
senza modificare i container che usano `Always`. Usa una mutation
`ApplyConfiguration` e CEL `map()`. Verifica entrambi i container di
`pod.yaml`.

---

### Q4 – Kyverno label applicative obbligatorie

Percorso: `~/course-policy-exam/04`.

Completa `require-app-labels` per negare CREATE e UPDATE di Deployment in
`production` quando mancano `app.kubernetes.io/name` o
`app.kubernetes.io/part-of`. Usa una sola validation CEL e un messaggio utile.
Dimostra `bad.yaml` negato e `good.yaml` ammesso.

---

### Q5 – Kyverno immagini pinned

Percorso: `~/course-policy-exam/05`.

Correggi `require-pinned-images`: deve controllare container e initContainer,
negare `:latest` e immagini senza tag o digest, e accettare tag espliciti e
digest. Testa `bad.yaml`, `tagged.yaml` e `digest.yaml` con CLI e admission.

---

### Q6 – Kyverno transizione dello stato audit

Percorso: `~/course-policy-exam/06`.

Crea una `NamespacedValidatingPolicy` `protect-audit-state` in `caribbean` che
si applichi soltanto agli UPDATE dei Pod. Consenti:

- `pending` invariato;
- la transizione `pending` -> `passed` o `pending` -> `failed`;
- `passed` e `failed` invariati.

Nega rimozione della label, ritorno a `pending` e qualsiasi altro valore. Usa
`object` e `oldObject`; verifica le patch fornite sul Pod iniziale.

---

### Q7 – Kyverno rollout Audit verso Deny

Percorso: `~/course-policy-exam/07`.

Completa `require-cost-center` per Deployment. Inizia con
`validationActions: [Audit]`, applica la policy e individua il Deployment
esistente non conforme nel PolicyReport. Correggilo, porta la policy a `Deny`
e dimostra che `new-bad.yaml` viene rifiutato.

---

### Q8 – Kyverno securityContext per container

Percorso: `~/course-policy-exam/08`.

Completa la mutation affinché ogni container mantenga nome e immagine e riceva
come default `allowPrivilegeEscalation: false` e
`capabilities.drop: ["ALL"]`. Non sovrascrivere un valore già presente. Il
Pod contiene due container con configurazioni differenti: verifica entrambi.

---

### Q9 – Kyverno namespaceSelector ed esclusione

Percorso: `~/course-policy-exam/09`.

Correggi la policy cluster-scoped affinché richieda `security-reviewed=true`
ai Pod nei Namespace con label `policy.kyverno.io/enabled=true`, escludendo
quelli con `policy.kyverno.io/exempt=true`. Dimostra il comportamento in
`team-a`, `team-b` ed `exempt` con i manifest forniti.

---

### Q10 – Kyverno troubleshooting UPDATE

Percorso: `~/course-policy-exam/10`.

La policy dovrebbe aggiungere `managed-by: kyverno` durante CREATE e UPDATE,
ma il Pod creato riceve la label e un Pod legacy aggiornato no. Diagnostica e
correggi `policy.yaml` senza cambiare nome o scope. Usa `kubectl explain`, lo
stato della policy e i log admission; salva causa e verifica in
`evidence.txt`.

---

### Q11 – Gatekeeper owner label parametrica

Percorso: `~/course-policy-exam/11`.

Completa `ConstraintTemplate` e Constraint per richiedere la label indicata
da `parameters.label` ai Deployment in `apps`. Il kind deve essere
`RequiredMetadataLabel`, la Constraint `require-owner`, il parametro `owner`
e l'enforcement `deny`. Verifica manifest negativo e positivo.

---

### Q12 – Gatekeeper repository consentiti

Percorso: `~/course-policy-exam/12`.

Completa `AllowedRepositories` per controllare container e initContainer e
consentire solo immagini con prefisso `registry.k8s.io/` o
`ghcr.io/company/`. Il messaggio deve includere nome container e immagine.
Verifica `bad.yaml` negato e `good.yaml` ammesso.

---

### Q13 – Gatekeeper requests e limits

Percorso: `~/course-policy-exam/13`.

Completa `RequiredResources` affinché ogni container e initContainer abbia
request e limit di CPU e memoria. La Constraint agisce sui Pod in
`production`. Correggi `pod.yaml` dopo il primo diniego e dimostra
l'accettazione.

---

### Q14 – Gatekeeper namespaceSelector

Percorso: `~/course-policy-exam/14`.

Riusa il template fornito e completa solo la Constraint: richiedi annotation
`owner` ai Deployment nei Namespace con
`policy.gatekeeper/enabled=true`, ma escludi i Namespace con
`policy.gatekeeper/exempt=true`. Non usare una lista statica di Namespace.

---

### Q15 – Gatekeeper dryrun e audit

Percorso: `~/course-policy-exam/15`.

Completa il template fornito e crea `audit-environment` con
`enforcementAction: dryrun` per richiedere la label `environment` ai
Deployment in `team-a`. Un workload non conforme è già presente. Dimostra che
un nuovo workload non viene bloccato e raccogli da `status.violations` nome,
Namespace e messaggio dell'oggetto esistente.

---

### Q16 – Gatekeeper warn verso deny

Percorso: `~/course-policy-exam/16`.

Completa il template fornito e configura inizialmente `warn-team` con
`enforcementAction: warn` sui Pod in `apps`, salva il warning prodotto ma
dimostra che il Pod viene creato. Elimina il Pod, cambia solo l'enforcement in
`deny` e dimostra che lo stesso manifest viene rifiutato.

---

### Q17 – Gatekeeper host Ingress univoco

Percorso: `~/course-policy-exam/17`.

Completa il `Config` di sync e il template che usa `data.inventory` per
impedire host Ingress duplicati tra Namespace. `duplicate.yaml` deve essere
negato perché l'host esiste già. Un UPDATE dell'Ingress originale deve essere
ammesso: escludi l'oggetto stesso dal confronto.

---

### Q18 – Gatekeeper mutation metadata condizionale

Percorso: `~/course-policy-exam/18`.

Completa una risorsa Gatekeeper `AssignMetadata` chiamata
`default-data-classification` che aggiunga la label
`data-classification: internal` ai Pod in `apps` soltanto se la label non è
già definita. Verifica che `missing.yaml` venga mutato e `existing.yaml`
mantenga `restricted`.

---

### Q19 – Gatekeeper ConstraintTemplate non operativo

Percorso: `~/course-policy-exam/19`.

Il ConstraintTemplate `DisallowHostNetwork` non genera una policy operativa.
Trova e correggi gli errori di schema, target/Rego e corrispondenza del kind.
Attendi la CRD, applica la Constraint e dimostra che `bad.yaml` viene negato e
`good.yaml` ammesso. Documenta i segnali diagnostici usati.

---

### Q20 – Capstone: mutation Kyverno e validation Gatekeeper

Percorso: `~/course-policy-exam/20`.

Nel Namespace `finale` devono cooperare due motori:

1. Kyverno aggiunge `audit: pending` ai Pod solo se la label manca, durante
   CREATE e UPDATE.
2. Completa il ConstraintTemplate Gatekeeper e nega i Pod privi di label
   `owner`.
3. `bad.yaml` deve essere negato da Gatekeeper.
4. `good.yaml` deve essere ammesso e risultare con `owner: platform` e
   `audit: pending`.
5. Porta `audit` a `passed`, aggiorna un'altra annotation e dimostra che
   Kyverno non sovrascrive il valore.
6. Salva policy, output admission e Pod finale in `evidence.txt`.

Se il risultato non è quello atteso, individua quale webhook è intervenuto
usando messaggi admission, eventi e log, senza disabilitare alcun motore.
