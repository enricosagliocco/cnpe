# Crossplane v2 - 20 prove XRD, Composition e XR

Crossplane e `function-patch-and-transform` sono installati. Ogni domanda e'
indipendente: lavora solo nella directory indicata e salva i manifest finali
come `xrd.yaml`, `composition.yaml` e `xr.yaml`.

Focus delle prove:

- `type: FromCompositeFieldPath` copia dati dall'XR verso una risorsa composta;
- `type: ToCompositeFieldPath` copia dati osservati da una risorsa composta
  verso lo `status` dell'XR;
- nelle risposte usa sempre `type` esplicito, anche quando
  `FromCompositeFieldPath` sarebbe il default.

Prima di iniziare:

```bash
kubectl get functions
kubectl api-resources | grep -i crossplane
kubectl get events -A --sort-by=.lastTimestamp
```

Per ogni prova verifica almeno:

```bash
kubectl get xrd
kubectl get compositions
kubectl describe <kind-xr> <nome>
```

---

### Q1 - Creare una XRD cluster-scoped

Lavora in `~/course-crossplane/01`. Ricrea `xrd.yaml` per esporre
`TeamSpace` (`teamspaces.platform.example.com`) in `v1alpha1`, scope
`Cluster`, con `spec.projectId` stringa obbligatoria. Applica XRD e
Composition, poi crea `team-alpha` con `projectId: alpha-123`.

Verifica XR, Namespace `team-alpha` e NetworkPolicy
`default-deny-ingress`.

---

### Q2 - Creare una XRD namespaced

Lavora in `~/course-crossplane/02`. La XRD deve essere `Namespaced`.
Crea Namespace `exam`, applica i manifest e crea `ProjectSpace/payments`
nel Namespace `exam`, con `owner: finance`.

Verifica che ConfigMap e Secret composti siano nello stesso Namespace
dell'XR e che nessun Namespace sia stato creato dalla Composition.

---

### Q3 - Schema OpenAPI, default e validazione

Lavora in `~/course-crossplane/03`. Estendi lo schema di
`EnvironmentSpace` con:

- `spec.environment`: obbligatorio, enum `dev`, `staging`, `prod`;
- `spec.replicas`: integer, default `2`, minimo `1`, massimo `10`;
- `spec.region`: stringa, default `eu-west-1`;
- rifiuto dei campi sconosciuti dentro `spec`.

Crea `staging-blue` omettendo i campi con default. Dimostra anche che un
XR con `environment: test` viene rifiutato.

---

### Q4 - Versioni served e referenceable

Lavora in `~/course-crossplane/04`. Modifica la XRD `CostSpace` affinche':

- `v1alpha1` sia `served: true`, `referenceable: false`;
- `v1beta1` sia `served: true`, `referenceable: true`;
- entrambe espongano `spec.costCenter`.

Aggiorna `compositeTypeRef` e `xr.yaml` a `v1beta1`, quindi crea `billing`.
Verifica le versioni pubblicate con `kubectl get xrd ... -o yaml`.

---

### Q5 - Composition pipeline minima

Lavora in `~/course-crossplane/05`. Ricrea `composition.yaml` usando
`mode: Pipeline` e `function-patch-and-transform`. Deve comporre:

- Namespace con nome uguale all'XR;
- ConfigMap `product-config` nel Namespace appena creato;
- `data.productId` derivato da `spec.productId`.

Tutte le patch dall'XR devono dichiarare esplicitamente
`type: FromCompositeFieldPath`.

Crea `ProductSpace/catalog` con `productId: product-88`.

---

### Q6 - FromCompositeFieldPath e propagazione metadata

Lavora in `~/course-crossplane/06`. Aggiungi alla XRD i campi obbligatori
`spec.tenantId` e `spec.owner`. Nella Composition propaga:

- nome XR al nome Namespace;
- `tenantId` all'annotazione `platform.example.com/tenant-id`;
- `owner` alla label `platform.example.com/owner`;
- entrambe le proprieta' nella ConfigMap `tenant-config`.

Per ciascuna patch usa esplicitamente:

```yaml
type: FromCompositeFieldPath
```

Imposta `policy.fromFieldPath: Required` almeno per `spec.tenantId`, quindi
prova a spiegare la differenza rispetto alla policy opzionale predefinita.

Crea `tenant-acme` e verifica label, annotation e data.

---

### Q7 - CombineFromComposite

Lavora in `~/course-crossplane/07`. Aggiungi `spec.region` allo schema.
Nella risorsa ConfigMap usa una patch `CombineFromComposite` con strategia
`string` e formato `%s@%s` per produrre:

```yaml
data:
  endpoint: edge-west-01@eu-central-1
```

I valori devono provenire da `spec.clusterName` e `spec.region`.
Confronta questa patch con due patch separate di tipo
`FromCompositeFieldPath`.

---

### Q8 - String transform su XR namespaced

Lavora in `~/course-crossplane/08`. Mantieni l'XR namespaced. Applica una
transform stringa `Format` per scrivere nella ConfigMap:

```yaml
data:
  location: region-eu-west-1
```

partendo da `spec.region: eu-west-1`. Crea l'XR `apps-eu` in `exam` e
verifica che tutte le risorse composte restino in `exam`.
La patch con transform deve mantenere `type: FromCompositeFieldPath`.

---

### Q9 - Map transform

Lavora in `~/course-crossplane/09`. Estendi lo schema con
`spec.accountTier`, enum `dev`, `prod`. Usa una transform `map` per
convertire:

- `dev` in `small`;
- `prod` in `large`.

Scrivi il risultato in `data.size` di `account-config`. Crea
`shared-services` con `accountId: "123456789012"` e `accountTier: prod`.
La transform deve essere applicata a una patch esplicita
`FromCompositeFieldPath`.

---

### Q10 - PatchSet riutilizzabile

Lavora in `~/course-crossplane/10`. Definisci un PatchSet `common-metadata`
che propaghi dall'XR le label `team` e `cost-center`. Applica il PatchSet
sia al Namespace sia alla ConfigMap, senza duplicare le due patch.

Aggiungi i campi allo schema e crea `ApplicationSpace/checkout`.

---

### Q11 - Scrivere nello status dell'XR

Lavora in `~/course-crossplane/11`. Aggiungi allo schema:

```yaml
status:
  type: object
  properties:
    namespace:
      type: string
```

Usa una patch `ToCompositeFieldPath` dalla risorsa Namespace per valorizzare
`status.namespace` con il nome osservato. Crea `DomainSpace/orders` e
attendi che lo status sia valorizzato.

Aggiungi anche `status.observedDomain` allo schema e valorizzalo leggendo
l'annotazione `platform.example.com/domain` dalla risorsa Namespace. In
questa domanda entrambe le patch verso lo status devono dichiarare:

```yaml
type: ToCompositeFieldPath
```

Verifica che la direzione sia risorsa composta -> XR e non XR -> risorsa.

---

### Q12 - Readiness checks

Lavora in `~/course-crossplane/12`. Sostituisci `readinessChecks: None` per
la ConfigMap con un check `MatchString` che richieda
`data.ready: "true"`. Imposta il valore nella base o tramite patch.

Crea `ServiceSpace/identity` in `exam` e verifica le condizioni `Ready` e
`Synced` dell'XR.

---

### Q13 - Selezione della Composition

Lavora in `~/course-crossplane/13`. Applica anche
`composition-restricted.yaml`. Etichetta la Composition standard con
`platform.example.com/profile: standard`.

Crea `DataSpace/analytics` con:

```yaml
spec:
  crossplane:
    compositionSelector:
      matchLabels:
        platform.example.com/profile: restricted
```

e `classification: confidential`. Verifica quale Composition e revisione
sono state selezionate e la label Pod Security del Namespace.

---

### Q14 - Troubleshooting della pipeline

Lavora in `~/course-crossplane/14`. Applica XRD e
`composition-broken.yaml`, forza l'XR a selezionare
`securityspace-broken` tramite `spec.crossplane.compositionRef.name` e
diagnostica il mancato reconcile.

Correggi la Composition affinche' usi la Function installata e produca
almeno un Namespace. Conserva in `evidence.txt` eventi e condizioni prima
e dopo la correzione.

---

### Q15 - CompositionRevision automatica

Lavora in `~/course-crossplane/15`. Crea `ComplianceSpace/pci-workloads`.
Annota la revisione selezionata. Modifica la Composition aggiungendo la
label `compliance: pci-dss` al Namespace e riapplicala.

Con policy `Automatic`, verifica che l'XR passi alla nuova
CompositionRevision e che la label venga propagata.

---

### Q16 - CompositionRevision manuale

Lavora in `~/course-crossplane/16`. Crea `RuntimeSpace/java-services` con:

```yaml
spec:
  crossplane:
    compositionUpdatePolicy: Manual
```

Modifica la Composition aggiungendo `data.generation: "v2"` alla ConfigMap.
Dimostra che l'XR resta sulla vecchia revisione, poi imposta esplicitamente
`spec.crossplane.compositionRevisionRef.name` alla nuova revisione.

---

### Q17 - Update e riconciliazione

Lavora in `~/course-crossplane/17`. Crea `ReleaseSpace/canary` con
`releaseChannel: canary`, poi aggiorna il valore a `stable`.

Verifica che Crossplane aggiorni annotation del Namespace e data della
ConfigMap senza ricreare l'XR. Registra in `evidence.txt` UID dell'XR e
valori prima/dopo.

---

### Q18 - Pausa e ripresa di un XR

Lavora in `~/course-crossplane/18`. Crea `ObservabilitySpace/sre-tools` in
`exam`, poi aggiungi l'annotation:

```yaml
crossplane.io/paused: "true"
```

Modifica `spec.monitoringProfile` e dimostra che la ConfigMap non cambia
durante la pausa. Rimuovi l'annotation e verifica la riconciliazione.

---

### Q19 - Debug completo XRD, Composition e XR

Lavora in `~/course-crossplane/19`. Introduci e poi risolvi, uno alla volta,
questi errori controllando eventi e condizioni:

1. `compositeTypeRef.kind` non corrispondente alla XRD;
2. `fromFieldPath` che punta a un campo inesistente con policy `Required`;
3. XR privo del campo obbligatorio `backupPolicy`.

La soluzione finale deve creare `BackupSpace/critical-backups` e tutte le
risorse composte. Salva i comandi diagnostici in `evidence.txt`.

---

### Q20 - Simulazione end-to-end da zero

Lavora in `~/course-crossplane/20`. I tre manifest contengono solo TODO.
Crea da zero:

- XRD cluster-scoped `PlatformSpace`, gruppo `platform.example.com`,
  versione `v1alpha1`;
- schema con `platformOwner` obbligatorio, `environment` enum
  `dev|staging|prod` e default `dev`, piu' `status.namespace`;
- Composition Pipeline con Namespace e ConfigMap `platform-config`;
- patch di nome, owner, environment e una patch verso lo status;
- almeno tre patch esplicite `FromCompositeFieldPath` e una
  `ToCompositeFieldPath`;
- readiness check espliciti;
- XR `developer-portal` con owner `platform-team` e environment `prod`.

Verifica XRD Established, Function Healthy, Composition valida, XR
Ready/Synced, resource references, Namespace, ConfigMap e status.

---

## Soluzioni

Le soluzioni seguenti indicano il costrutto decisivo. Usa
`kubectl explain`, gli eventi e i manifest gia' presenti per completare il
contesto senza sostituire alla cieca file interi.

### Soluzione Q1 - XRD cluster-scoped

La XRD usa `apiextensions.crossplane.io/v2`, `spec.scope: Cluster`,
`spec.names.kind: TeamSpace`, `plural: teamspaces` e include
`required: [projectId]`. Applica nell'ordine:

```bash
kubectl apply -f xrd.yaml
kubectl wait --for=condition=Established xrd/teamspaces.platform.example.com
kubectl apply -f composition.yaml -f xr.yaml
kubectl get teamspace team-alpha
kubectl get ns team-alpha
kubectl -n team-alpha get netpol default-deny-ingress
```

### Soluzione Q2 - XRD namespaced

Usa `spec.scope: Namespaced` e `metadata.namespace: exam` nell'XR:

```bash
kubectl create ns exam --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f xrd.yaml -f composition.yaml -f xr.yaml
kubectl -n exam get projectspace,cm,secret
```

### Soluzione Q3 - Validazione

Nel campo `replicas` usa `default: 2`, `minimum: 1`, `maximum: 10`; per
`environment` usa `enum: [dev, staging, prod]`. In `spec` imposta
`additionalProperties: false`. Verifica:

```bash
kubectl get environmentspace staging-blue -o jsonpath='{.spec}'
kubectl apply -f invalid-xr.yaml
```

Il secondo comando deve fallire lato API server.

### Soluzione Q4 - Versioni

Duplica la voce sotto `spec.versions`, cambia `name`, `served` e
`referenceable`, quindi usa `platform.example.com/v1beta1` sia nella
Composition sia nell'XR.

### Soluzione Q5 - Pipeline

La struttura richiesta e':

```yaml
spec:
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources: []
```

Inserisci nelle `resources` le basi Namespace e ConfigMap e patch
`metadata.name`, `metadata.namespace`, `data.productId`, tutte con:

```yaml
type: FromCompositeFieldPath
```

### Soluzione Q6 - Metadata

Usa path con chiave quotata:

```yaml
- type: FromCompositeFieldPath
  fromFieldPath: spec.owner
  toFieldPath: metadata.labels[platform.example.com/owner]
- type: FromCompositeFieldPath
  fromFieldPath: spec.tenantId
  toFieldPath: metadata.annotations[platform.example.com/tenant-id]
  policy:
    fromFieldPath: Required
```

`FromCompositeFieldPath` legge dal composite corrente e scrive nella
risorsa composta indicata dalla voce `resources`.

### Soluzione Q7 - Combine

```yaml
- type: CombineFromComposite
  combine:
    variables:
      - fromFieldPath: spec.clusterName
      - fromFieldPath: spec.region
    strategy: string
    string:
      fmt: "%s@%s"
  toFieldPath: data.endpoint
```

### Soluzione Q8 - String transform

```yaml
- type: FromCompositeFieldPath
  fromFieldPath: spec.region
  toFieldPath: data.location
  transforms:
    - type: string
      string:
        type: Format
        fmt: "region-%s"
```

### Soluzione Q9 - Map transform

```yaml
type: FromCompositeFieldPath
fromFieldPath: spec.accountTier
toFieldPath: data.size
transforms:
  - type: map
    map:
      dev: small
      prod: large
```

### Soluzione Q10 - PatchSet

Definisci `patchSets` nell'input `Resources`, poi nelle due risorse usa:

```yaml
- type: PatchSet
  patchSetName: common-metadata
```

### Soluzione Q11 - Status

```yaml
- type: ToCompositeFieldPath
  fromFieldPath: metadata.name
  toFieldPath: status.namespace
- type: ToCompositeFieldPath
  fromFieldPath: metadata.annotations[platform.example.com/domain]
  toFieldPath: status.observedDomain
```

Qui `fromFieldPath` parte dalla risorsa composta. Entrambi i campi
destinazione devono esistere nello schema XRD sotto `status`.

### Soluzione Q12 - Readiness

```yaml
readinessChecks:
  - type: MatchString
    fieldPath: data.ready
    matchString: "true"
```

### Soluzione Q13 - Selection

La label della Composition deve corrispondere al selector. Verifica con:

```bash
kubectl get dataspace analytics -o jsonpath='{.spec.crossplane.compositionRef.name}{"\n"}'
kubectl get dataspace analytics -o jsonpath='{.spec.crossplane.compositionRevisionRef.name}{"\n"}'
```

### Soluzione Q14 - Pipeline rotta

Gli eventi mostrano che `function-does-not-exist` non e' disponibile.
Sostituiscila con `function-patch-and-transform`, aggiungi una risorsa
Namespace valida e riapplica la Composition.

### Soluzione Q15 - Revisione automatica

```bash
kubectl get compositionrevisions -l crossplane.io/composition-name=compliance-composition
kubectl get compliancespace pci-workloads \
  -o jsonpath='{.spec.crossplane.compositionRevisionRef.name}{"\n"}'
```

Con `Automatic`, il riferimento cambia dopo l'aggiornamento.

### Soluzione Q16 - Revisione manuale

Recupera il nome della revisione nuova e applicalo:

```bash
kubectl patch runtimespace java-services --type=merge -p \
  '{"spec":{"crossplane":{"compositionRevisionRef":{"name":"REVISIONE"}}}}'
```

### Soluzione Q17 - Update

```bash
kubectl patch releasespace canary --type=merge -p \
  '{"spec":{"releaseChannel":"stable"}}'
kubectl get releasespace canary -o jsonpath='{.metadata.uid}{"\n"}'
kubectl -n canary get cm release-config -o jsonpath='{.data.releaseChannel}{"\n"}'
```

### Soluzione Q18 - Pausa

```bash
kubectl -n exam annotate observabilityspace sre-tools crossplane.io/paused=true
kubectl -n exam annotate observabilityspace sre-tools crossplane.io/paused-
```

### Soluzione Q19 - Debug

Comandi minimi:

```bash
kubectl get xrd,composition
kubectl describe composition backup-composition
kubectl describe backupspace critical-backups
kubectl get events -A --sort-by=.lastTimestamp
```

Allinea il `kind`, correggi il path o il campo nello schema/XR, quindi
aggiungi `spec.backupPolicy`.

Per rendere obbligatoria la sorgente:

```yaml
- type: FromCompositeFieldPath
  fromFieldPath: spec.backupPolicy
  toFieldPath: data.backupPolicy
  policy:
    fromFieldPath: Required
```

### Soluzione Q20 - End-to-end

La soluzione combina i costrutti di Q1, Q3, Q5, Q11 e Q12. Le patch da
`spec` o `metadata` dell'XR usano `FromCompositeFieldPath`; la patch da
`metadata.name` del Namespace verso `status.namespace` usa
`ToCompositeFieldPath`. Controllo finale:

```bash
kubectl wait --for=condition=Established xrd/platformspaces.platform.example.com
kubectl wait --for=condition=Healthy function/function-patch-and-transform
kubectl get platformspace developer-portal -o yaml
kubectl get ns developer-portal -o yaml
kubectl -n developer-portal get cm platform-config -o yaml
kubectl describe platformspace developer-portal
```
