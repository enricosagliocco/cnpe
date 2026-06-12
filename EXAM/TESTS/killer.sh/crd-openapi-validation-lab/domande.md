# CRD OpenAPI Validation - 20 prove in stile CNPE

Ogni domanda e' indipendente. Lavora nella directory indicata, completa
`crd.yaml`, usa `valid.yaml` e `invalid.yaml` per verificare il comportamento
dell'API server e salva i comandi significativi in `evidence.txt`.

Il CNPE assegna il 25% al dominio **Platform APIs and Self-Service
Capabilities**, che include la progettazione di CRD per servizi di piattaforma.
L'esame e' pratico, dura 120 minuti e comprende 15-20 task. Queste prove
privilegiano quindi modifiche brevi, verifica server-side e troubleshooting.

Comandi utili:

```bash
kubectl apply --server-side --dry-run=server -f crd.yaml
kubectl wait --for=condition=Established crd/<nome>
kubectl explain <risorsa>.spec
kubectl get events -A --sort-by=.lastTimestamp
```

Riferimenti verificati il 12 giugno 2026:

- https://www.cncf.io/training/certification/cnpe/
- https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cnpe
- https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/

---

### Q1 - CRD con validation e defaulting

Lavora in `~/course-crd-openapi/01`.

Completa `crd.yaml` per creare la CRD namespaced
`platformservices.platform.killercoda.com`.

Lo schema di `spec` deve contenere:

- `serviceName`: stringa obbligatoria;
- `tier`: stringa obbligatoria, enum `bronze`, `silver`, `gold`;
- `replicas`: integer opzionale, default `1`, minimo `1`, massimo `10`.

Applica la CRD e attendi `Established=True`. Applica `valid.yaml` e verifica
che `spec.replicas` sia stato impostato a `1`. `invalid.yaml` deve essere
rifiutato.

**Tip**

Definisci `type: object` sia alla root sia per `spec`. La lista `required`
appartiene allo schema dell'object che contiene i campi.

---

### Q2 - Campi required e default

Lavora in `~/course-crd-openapi/02`.

Definisci `AppService` con:

- `spec.name`: stringa obbligatoria;
- `spec.image`: stringa obbligatoria;
- `spec.environment`: enum `dev|staging|prod`, default `dev`;
- `spec.replicas`: integer, default `1`, range `1-5`.

Completa i due manifest di test. La risorsa valida deve omettere i campi con
default; quella non valida deve omettere `image`.

Verifica il default persistito e l'errore relativo al campo required.

---

### Q3 - Pattern e lunghezza delle stringhe

Lavora in `~/course-crd-openapi/03`.

Lo schema di `RouteService` deve richiedere:

- `spec.host`, pattern DNS semplificato
  `^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)+$`;
- `spec.path`, stringa che inizia con `/`;
- `spec.owner`, lunghezza minima `3`, massima `30`.

Crea una risorsa valida e una con host, path e owner non conformi. Salva in
`evidence.txt` i messaggi restituiti dall'API server.

---

### Q4 - Range numerico e multipleOf

Lavora in `~/course-crd-openapi/04`.

Definisci `WorkerService` con:

- `spec.replicas`: integer `1-20`, default `2`;
- `spec.cpuMillicores`: integer `100-4000`, multiplo di `100`;
- `spec.timeoutSeconds`: number maggiore di `0` e massimo `60`.

Verifica che `cpuMillicores: 750` e `timeoutSeconds: 0` siano rifiutati.

---

### Q5 - Array con enum e unicita'

Lavora in `~/course-crd-openapi/05`.

Definisci `AccessProfile` con `spec.roles`:

- array obbligatorio;
- minimo un elemento, massimo quattro;
- elementi stringa enum `reader`, `developer`, `operator`, `admin`;
- valori unici.

Aggiungi `spec.namespaces` come array di stringhe con almeno un elemento.
Verifica una risorsa valida e una con ruolo duplicato e valore non ammesso.

---

### Q6 - Object annidato

Lavora in `~/course-crd-openapi/06`.

Definisci `DatabaseService` con:

- `spec.engine`: enum `postgres|mysql`;
- `spec.storage`: object obbligatorio;
- `spec.storage.sizeGi`: integer `1-500`;
- `spec.storage.className`: stringa obbligatoria;
- `spec.backup.enabled`: boolean, default `false`;
- `spec.backup.retentionDays`: integer `1-30`, default `7`.

Rendi obbligatori `engine`, `storage`, `sizeGi` e `className`. Verifica che
un object `storage` incompleto venga rifiutato.

---

### Q7 - Mappa tipizzata

Lavora in `~/course-crd-openapi/07`.

Definisci `TeamConfig` con:

- `spec.team`: stringa obbligatoria;
- `spec.variables`: object i cui valori aggiuntivi siano soltanto stringhe;
- massimo 20 proprieta' nella mappa;
- `spec.labels`: object con valori stringa che rispettano
  `^[a-z0-9A-Z_.-]+$`.

Verifica che un valore numerico dentro `variables` venga rifiutato.

---

### Q8 - Pruning dei campi sconosciuti

Lavora in `~/course-crd-openapi/08`.

Definisci uno schema strutturale per `BuildRequest` con:

- `spec.repository`: stringa obbligatoria;
- `spec.revision`: stringa, default `main`;
- `spec.builder`: enum `docker|buildpacks`.

Nel manifest valido aggiungi anche `spec.debug: true`, che non deve essere
definito nello schema. Applica la risorsa e dimostra che `debug` viene rimosso
prima della persistenza.

---

### Q9 - Preservare una subtree arbitraria

Lavora in `~/course-crd-openapi/09`.

Definisci `PluginConfig` con:

- `spec.pluginName`: stringa obbligatoria;
- `spec.config`: object con `x-kubernetes-preserve-unknown-fields: true`.

La CRD deve continuare a rimuovere campi sconosciuti direttamente sotto
`spec`, ma deve conservare JSON arbitrario dentro `spec.config`.

Dimostra entrambi i comportamenti con il manifest valido.

---

### Q10 - Nullable e default

Lavora in `~/course-crd-openapi/10`.

Definisci `CachePolicy` con:

- `spec.strategy`: enum `lru|lfu`, default `lru`;
- `spec.maxEntries`: integer, default `1000`, minimo `1`;
- `spec.description`: stringa `nullable: true`.

Crea una risorsa con tutti e tre i campi impostati a `null`. Verifica che i
campi non nullable ricevano il default e che `description` rimanga `null`.

---

### Q11 - CEL tra due campi

Lavora in `~/course-crd-openapi/11`.

Definisci `CapacityPlan` con `spec.minReplicas` e `spec.maxReplicas`, entrambi
integer nel range `1-50`.

Aggiungi una regola CEL su `spec`:

```text
self.minReplicas <= self.maxReplicas
```

Usa `message` per restituire un errore leggibile. Verifica che una richiesta
con minimo `10` e massimo `3` venga rifiutata.

---

### Q12 - CEL condizionale

Lavora in `~/course-crd-openapi/12`.

Definisci `ServicePlan` con:

- `spec.tier`: enum `bronze|silver|gold`;
- `spec.replicas`: integer `1-10`.

Aggiungi una regola CEL: quando `tier` e' `gold`, `replicas` deve essere almeno
`3`. Gli altri tier possono usare una replica.

Verifica una richiesta `gold` valida e una con una sola replica.

---

### Q13 - Campo immutabile con oldSelf

Lavora in `~/course-crd-openapi/13`.

Definisci `ProjectRequest` con `spec.projectId` e `spec.owner`, entrambi
obbligatori. Rendi `projectId` immutabile tramite:

```text
self == oldSelf
```

Crea una risorsa, aggiorna `owner` con successo e dimostra che la modifica di
`projectId` viene rifiutata.

---

### Q14 - Status subresource

Lavora in `~/course-crd-openapi/14`.

Definisci `ManagedService` con:

- `spec.serviceName` stringa obbligatoria;
- `status.phase` enum `Pending|Ready|Failed`;
- `status.message` stringa;
- subresource `status` abilitata.

Crea una risorsa e aggiorna lo status con:

```bash
kubectl -n exam patch managedservice <nome> \
  --subresource=status --type=merge \
  -p '{"status":{"phase":"Ready","message":"Provisioned"}}'
```

Verifica che lo status sia presente senza modificare `spec`.

---

### Q15 - Additional printer columns

Lavora in `~/course-crd-openapi/15`.

Definisci `CatalogEntry` con `spec.owner`, `spec.tier`, `spec.replicas` e
`status.phase`. Aggiungi le colonne:

- `Owner` da `.spec.owner`;
- `Tier` da `.spec.tier`;
- `Replicas` integer da `.spec.replicas`;
- `Phase` da `.status.phase`;
- `Age` date da `.metadata.creationTimestamp`.

Applica una risorsa e verifica l'output di `kubectl get catalogentries`.

---

### Q16 - Scale subresource

Lavora in `~/course-crd-openapi/16`.

Definisci `ScalableApp` con:

- `spec.replicas`: integer `1-10`, default `1`;
- `status.replicas`: integer;
- `status.selector`: stringa;
- subresource `status`;
- subresource `scale` con i path corretti.

Applica una risorsa e usa:

```bash
kubectl -n exam scale scalableapp <nome> --replicas=5
```

Verifica che `.spec.replicas` sia diventato `5`.

---

### Q17 - Discovery della platform API

Lavora in `~/course-crd-openapi/17`.

Definisci `DiscoverableService` con `spec.owner` e `spec.tier`. Configura:

- short name `ds`;
- categoria `all`;
- printer columns `Owner` e `Tier`;
- `.spec.tier` come selectable field.

Crea due risorse con tier differenti. Verifica short name, `kubectl get all`
e il field selector:

```bash
kubectl -n exam get ds --field-selector spec.tier=gold
```

---

### Q18 - Versioni served e storage

Lavora in `~/course-crd-openapi/18`.

La CRD contiene `v1alpha1` e `v1`, ma entrambe dichiarano `storage: true`.
Correggila affinche':

- entrambe siano `served: true`;
- solo `v1` sia storage;
- entrambe abbiano schema strutturale;
- `spec.channel` sia required ed enum `stable|fast`.

Applica una risorsa tramite `v1alpha1` e verifica che sia leggibile tramite
`v1`.

---

### Q19 - Troubleshooting di una CRD non valida

Lavora in `~/course-crd-openapi/19`.

`crd.yaml` deve essere rifiutato perche':

- manca `type: object` alla root;
- manca il tipo di `spec`;
- il default stringa `invalid` non e' valido per un integer.

Correggi la CRD. Lo schema finale di `BrokenService` deve avere
`spec.replicas` integer con default `1`, minimo `1`, massimo `10`.

Salva in `evidence.txt` l'errore iniziale e la condizione `Established` finale.

---

### Q20 - Simulazione finale da zero

Lavora in `~/course-crd-openapi/20`.

Crea da zero la CRD namespaced
`productionservices.platform.killercoda.com`:

- group `platform.killercoda.com`;
- version `v1`;
- kind `ProductionService`;
- plural `productionservices`, singular `productionservice`;
- short name `prod`;
- categoria `all`.

Schema:

- `spec.serviceName`: stringa required, pattern `^[a-z][a-z0-9-]{2,30}$`;
- `spec.owner`: stringa required, minimo 3 caratteri;
- `spec.tier`: required, enum `bronze|silver|gold`;
- `spec.replicas`: integer default `1`, range `1-10`;
- `spec.regions`: array required, da 1 a 3 stringhe uniche;
- CEL: tier `gold` richiede almeno 3 repliche;
- `status.phase`: enum `Pending|Ready|Failed`;
- status subresource;
- colonne `Owner`, `Tier`, `Replicas`, `Phase`.

Crea `ProductionService/storefront` nel Namespace `exam`, verifica default,
colonne e `kubectl explain`. Crea anche una richiesta non valida e dimostra
che viene rifiutata.

---

## Tracce di soluzione

### Soluzione Q1

Il blocco decisivo e':

```yaml
openAPIV3Schema:
  type: object
  properties:
    spec:
      type: object
      required:
        - serviceName
        - tier
      properties:
        serviceName:
          type: string
        tier:
          type: string
          enum: [bronze, silver, gold]
        replicas:
          type: integer
          default: 1
          minimum: 1
          maximum: 10
```

### Soluzioni Q2-Q10

Usa i keyword OpenAPI nel nodo corretto:

- `required` sull'object che contiene le proprieta';
- `enum`, `pattern`, `minLength`, `maxLength` sulle stringhe;
- `minimum`, `maximum`, `multipleOf` sui numeri;
- `items`, `minItems`, `maxItems`, `uniqueItems` sugli array;
- `additionalProperties` per tipizzare una mappa;
- `x-kubernetes-preserve-unknown-fields` soltanto sulla subtree libera;
- `nullable: true` quando `null` deve essere conservato.

Verifica sempre contro l'API server:

```bash
kubectl apply --server-side --dry-run=server -f crd.yaml
kubectl apply -f crd.yaml
kubectl apply -f valid.yaml
kubectl apply -f invalid.yaml
```

### Soluzioni Q11-Q13

Le regole CEL si dichiarano con `x-kubernetes-validations`. Esempio:

```yaml
x-kubernetes-validations:
  - rule: "self.minReplicas <= self.maxReplicas"
    message: "minReplicas must not exceed maxReplicas"
```

Per un campo immutabile, applica al campo:

```yaml
x-kubernetes-validations:
  - rule: "self == oldSelf"
    message: "projectId is immutable"
```

### Soluzioni Q14-Q17

`subresources`, `additionalPrinterColumns` e `selectableFields` appartengono
alla singola voce sotto `spec.versions`.

Per scale:

```yaml
subresources:
  status: {}
  scale:
    specReplicasPath: .spec.replicas
    statusReplicasPath: .status.replicas
    labelSelectorPath: .status.selector
```

### Soluzione Q18

Una sola versione puo' avere `storage: true`. Entrambe possono essere
`served: true`; la conversione tra schemi identici usa la strategia predefinita
`None`.

### Soluzione Q19

Aggiungi `type: object` alla root e a `spec`, poi usa un default integer:

```yaml
replicas:
  type: integer
  default: 1
  minimum: 1
  maximum: 10
```

### Soluzione Q20

Combina schema strutturale, required, enum, default, array, CEL, status e
printer columns. Controllo finale:

```bash
kubectl apply --server-side --dry-run=server -f crd.yaml
kubectl apply -f crd.yaml
kubectl wait --for=condition=Established \
  crd/productionservices.platform.killercoda.com
kubectl apply -f valid.yaml
kubectl -n exam get prod
kubectl explain productionservice.spec
kubectl apply -f invalid.yaml
```
