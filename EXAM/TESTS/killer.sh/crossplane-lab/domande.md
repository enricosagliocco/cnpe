# Crossplane - 20 prove in stile esame CNPE

Le prove sono modellate sul formato Killer.sh della domanda Crossplane fornita:
ambiente gia' installato, manifest parziali, una modifica mirata e verifica
finale sul cluster.

Il CNPE e' un esame pratico di 120 minuti con 15-20 task. Crossplane rientra
nel dominio **Platform APIs and Self-Service Capabilities (25%)**. L'obiettivo
non e' memorizzare ogni funzione Crossplane, ma saper:

- ispezionare XRD, Composition, Function e XR esistenti;
- creare una richiesta self-service tramite un XR;
- completare una Composition che genera risorse Kubernetes;
- propagare namespace e parametri con patch;
- verificare riconciliazione, condizioni, eventi e risorse composte;
- correggere rapidamente manifest incompleti o errati.

Crossplane e `function-patch-and-transform` sono gia' installati. Ogni domanda
e' indipendente. Lavora solo nella directory indicata.

Comandi iniziali utili:

```bash
kubectl get functions
kubectl get xrd
kubectl get compositions
kubectl get events -A --sort-by=.lastTimestamp
```

Riferimenti verificati il 12 giugno 2026:

- CNPE: https://www.cncf.io/training/certification/cnpe/
- istruzioni CNPE: https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cnpe
- XRD Crossplane: https://docs.crossplane.io/latest/composition/composite-resource-definitions/
- Compositions: https://docs.crossplane.io/latest/composition/compositions/
- Patch and Transform: https://docs.crossplane.io/latest/guides/function-patch-and-transform/

---

### Q1 - Esporre una API self-service

Lavora in `~/course-crossplane/01`.

La Composition `teamspace-composition` e' gia' presente. Completa
`xrd.yaml` per definire la API cluster-scoped `TeamSpace`:

- gruppo `platform.example.com`;
- versione `v1alpha1`;
- plural `teamspaces`;
- campo obbligatorio `spec.projectId` di tipo stringa.

Crea `TeamSpace/team-alpha` con `projectId: alpha-123`.

Verifica che l'XR sia `SYNCED=True`, `READY=True` e che esistano Namespace
`team-alpha` e NetworkPolicy `default-deny-ingress`.

---

### Q2 - Creare un XR namespaced

Lavora in `~/course-crossplane/02`.

Crossplane espone gia' la API namespaced `ProjectSpace`. Crea il Namespace
`exam` e completa `xr.yaml` per creare:

- nome `payments`;
- namespace `exam`;
- `spec.owner: finance`.

Applica i manifest forniti. Verifica che ConfigMap e Secret composti siano
nel Namespace `exam`. Non modificare la Composition per creare un nuovo
Namespace.

---

### Q3 - Correggere lo schema di una XRD

Lavora in `~/course-crossplane/03`.

Completa lo schema di `EnvironmentSpace`:

- `spec.environment` obbligatorio, valori `dev`, `staging`, `prod`;
- `spec.replicas` integer, default `2`, minimo `1`, massimo `10`;
- `spec.region` stringa, default `eu-west-1`;
- campi sconosciuti vietati dentro `spec`.

Crea `EnvironmentSpace/staging-blue` impostando solo
`environment: staging`. Verifica i default salvati dall'API server.

Dimostra infine che un XR con `environment: test` viene rifiutato.

---

### Q4 - Allineare versione XRD, Composition e XR

Lavora in `~/course-crossplane/04`.

La XRD `CostSpace` pubblica `v1alpha1` e `v1beta1`, ma la configurazione e'
incoerente. Correggila affinche':

- entrambe le versioni siano `served: true`;
- solo `v1beta1` sia `referenceable: true`;
- `spec.costCenter` sia disponibile in entrambe.

Aggiorna Composition e `xr.yaml` per usare `v1beta1`, quindi crea
`CostSpace/billing`. Verifica XR e risorse composte.

---

### Q5 - Completare una Composition Pipeline

Lavora in `~/course-crossplane/05`.

XRD e XR sono forniti. Ricrea `composition.yaml` usando:

- `mode: Pipeline`;
- Function `function-patch-and-transform`;
- un Namespace con nome uguale all'XR;
- una ConfigMap `product-config` nel Namespace composto;
- `data.productId` letto da `spec.productId`.

Crea `ProductSpace/catalog` con `productId: product-88`.
Usa patch esplicite `FromCompositeFieldPath` e verifica XR, Namespace e
ConfigMap.

---

### Q6 - Propagare parametri e metadata

Lavora in `~/course-crossplane/06`.

Completa XRD e Composition di `TenantSpace` affinche' l'XR accetti
`spec.tenantId` e `spec.owner`, entrambi obbligatori.

Propaga i valori alle risorse composte:

- `tenantId` nell'annotation `platform.example.com/tenant-id`;
- `owner` nella label `platform.example.com/owner`;
- entrambi nella ConfigMap `tenant-config`.

Crea `TenantSpace/tenant-acme`. Imposta la patch di `tenantId` come
`Required` e verifica annotation, label e dati della ConfigMap.

---

### Q7 - Costruire un valore da due campi

Lavora in `~/course-crossplane/07`.

La ConfigMap composta deve contenere:

```yaml
data:
  endpoint: edge-west-01@eu-central-1
```

Ottieni il valore combinando `spec.clusterName` e `spec.region` con una
patch `CombineFromComposite`, strategia stringa e formato `%s@%s`.

Crea l'XR con i valori richiesti e verifica il valore esatto nella ConfigMap.

---

### Q8 - Trasformare un campo in un XR namespaced

Lavora in `~/course-crossplane/08`.

Completa la patch della Composition per trasformare
`spec.region: eu-west-1` nel valore:

```yaml
data:
  location: region-eu-west-1
```

Usa una transform stringa `Format`. Crea l'XR `apps-eu` nel Namespace
`exam` e verifica che tutte le risorse composte siano nello stesso Namespace.

---

### Q9 - Mappare un profilo applicativo

Lavora in `~/course-crossplane/09`.

Estendi la XRD con `spec.accountTier`, enum `dev` o `prod`. Completa la
Composition affinche' la ConfigMap `account-config` contenga:

- `data.size: small` per `dev`;
- `data.size: large` per `prod`.

Usa una transform `map`. Crea `AccountSpace/shared-services` con
`accountId: "123456789012"` e `accountTier: prod`, poi verifica il risultato.

---

### Q10 - Riutilizzare patch comuni

Lavora in `~/course-crossplane/10`.

La Composition crea Namespace e ConfigMap. Evita di duplicare le patch per
le label `team` e `cost-center`:

1. definisci il PatchSet `common-metadata`;
2. applicalo a entrambe le risorse;
3. aggiungi i campi necessari allo schema XRD;
4. crea `ApplicationSpace/checkout`.

Verifica che entrambe le risorse abbiano le due label.

---

### Q11 - Pubblicare un risultato nello status

Lavora in `~/course-crossplane/11`.

Aggiungi allo schema di `DomainSpace`:

```yaml
status:
  type: object
  properties:
    namespace:
      type: string
    observedDomain:
      type: string
```

Nella risorsa Namespace aggiungi due patch `ToCompositeFieldPath`:

- `metadata.name` verso `status.namespace`;
- annotation `platform.example.com/domain` verso `status.observedDomain`.

Entrambe devono dichiarare esplicitamente:

```yaml
type: ToCompositeFieldPath
```

Crea `DomainSpace/orders` e attendi che entrambi i campi compaiano nello
status dell'XR.

---

### Q12 - Rendere significativa la readiness

Lavora in `~/course-crossplane/12`.

La ConfigMap composta usa un readiness check troppo permissivo. Sostituiscilo
con un check `MatchString` su:

```yaml
data:
  ready: "true"
```

Crea `ServiceSpace/identity` nel Namespace `exam`. Verifica prima la risorsa
composta, poi le condizioni `Synced` e `Ready` dell'XR.

---

### Q13 - Selezionare la Composition corretta

Lavora in `~/course-crossplane/13`.

Sono disponibili una Composition standard e
`composition-restricted.yaml`.

1. Applica entrambe.
2. Etichetta la standard con `platform.example.com/profile: standard`.
3. Crea `DataSpace/analytics` selezionando il profilo `restricted` tramite
   `spec.crossplane.compositionSelector.matchLabels`.
4. Imposta `classification: confidential`.

Verifica il nome della Composition selezionata, la CompositionRevision e le
label di sicurezza del Namespace composto.

---

### Q14 - Riparare una Composition non riconciliata

Lavora in `~/course-crossplane/14`.

Applica XRD, XR e `composition-broken.yaml`. L'XR deve usare
`securityspace-broken`, ma la riconciliazione fallisce.

Usando `kubectl describe`, condizioni ed eventi:

1. identifica il riferimento non valido alla Function;
2. correggi la Composition usando la Function installata;
3. aggiungi una risorsa Namespace valida;
4. riapplica e verifica `SYNCED=True` e `READY=True`.

Salva in `evidence.txt` i comandi diagnostici e le condizioni finali.

---

### Q15 - Aggiornare risorse gia' esistenti

Lavora in `~/course-crossplane/15`.

Crea `ComplianceSpace/pci-workloads` con i manifest forniti e annota la
CompositionRevision selezionata.

Estendi la Composition affinche' il Namespace composto abbia:

```yaml
metadata:
  labels:
    compliance: pci-dss
```

Riapplica la Composition. Senza ricreare l'XR, verifica che Crossplane generi
una nuova revisione, la selezioni automaticamente e aggiorni il Namespace.

---

### Q16 - Controllare un aggiornamento manuale

Lavora in `~/course-crossplane/16`.

Crea `RuntimeSpace/java-services` con
`spec.crossplane.compositionUpdatePolicy: Manual`.

Aggiungi alla ConfigMap composta:

```yaml
data:
  generation: "v2"
```

Riapplica la Composition e verifica che l'XR continui a usare la vecchia
revisione. Seleziona poi esplicitamente la nuova
`compositionRevisionRef.name` e verifica l'aggiornamento della ConfigMap.

---

### Q17 - Verificare la riconciliazione dopo un update

Lavora in `~/course-crossplane/17`.

Crea `ReleaseSpace/canary` con `releaseChannel: canary`. Registra in
`evidence.txt` UID dell'XR e valori osservati nelle risorse composte.

Aggiorna l'XR impostando `releaseChannel: stable`. Verifica che:

- annotation del Namespace e data della ConfigMap diventino `stable`;
- l'UID dell'XR non cambi;
- le condizioni finali siano `Synced=True` e `Ready=True`.

---

### Q18 - Mettere in pausa la riconciliazione

Lavora in `~/course-crossplane/18`.

Crea `ObservabilitySpace/sre-tools` nel Namespace `exam`.

1. Aggiungi `crossplane.io/paused: "true"` all'XR.
2. Modifica `spec.monitoringProfile`.
3. Verifica che la ConfigMap non venga aggiornata durante la pausa.
4. Rimuovi l'annotation.
5. Verifica che Crossplane applichi il nuovo valore.

---

### Q19 - Risolvere una catena di errori

Lavora in `~/course-crossplane/19`.

La configurazione di `BackupSpace` contiene tre problemi. Correggili:

- `compositeTypeRef.kind` non corrisponde alla XRD;
- una patch `Required` legge un campo inesistente;
- l'XR non imposta il campo obbligatorio `spec.backupPolicy`.

La soluzione finale deve creare `BackupSpace/critical-backups` e tutte le
risorse composte. Usa `kubectl describe` ed eventi per procedere un errore
alla volta. Salva i comandi usati in `evidence.txt`.

---

### Q20 - Task finale end-to-end

Lavora in `~/course-crossplane/20`.

I tre manifest contengono solo TODO. Crea:

- XRD cluster-scoped `PlatformSpace`, gruppo `platform.example.com`,
  versione `v1alpha1`;
- schema con `platformOwner` obbligatorio, `environment` enum
  `dev|staging|prod` con default `dev` e `status.namespace`;
- Composition Pipeline con Namespace e ConfigMap `platform-config`;
- patch per nome, owner ed environment;
- patch `ToCompositeFieldPath` dal nome del Namespace a `status.namespace`;
- readiness check espliciti;
- XR `developer-portal`, owner `platform-team`, environment `prod`.

Verifica XRD `Established`, Function `Healthy`, XR `Synced/Ready`, resource
references, Namespace, ConfigMap e status.

---

## Tracce di soluzione

Queste tracce indicano il costrutto decisivo. In una simulazione d'esame usa
prima `kubectl explain`, i manifest forniti e gli eventi.

### Soluzione Q1

Usa XRD `apiextensions.crossplane.io/v2`, `scope: Cluster`, schema OpenAPI
con `required: [projectId]`, quindi:

```bash
kubectl apply -f xrd.yaml
kubectl wait --for=condition=Established xrd/teamspaces.platform.example.com
kubectl apply -f composition.yaml -f xr.yaml
kubectl get teamspace team-alpha
kubectl get ns team-alpha
kubectl -n team-alpha get netpol default-deny-ingress
```

### Soluzione Q2

Imposta `metadata.namespace: exam` nell'XR. Con una XRD namespaced, copia
`metadata.namespace` dall'XR alle risorse composte.

```bash
kubectl create ns exam --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f xrd.yaml -f composition.yaml -f xr.yaml
kubectl -n exam get projectspace,cm,secret
```

### Soluzione Q3

Usa `enum`, `default`, `minimum`, `maximum`, `required` e
`additionalProperties: false` nello schema OpenAPI.

```bash
kubectl get environmentspace staging-blue -o jsonpath='{.spec}{"\n"}'
kubectl apply -f invalid-xr.yaml
```

### Soluzione Q4

Solo una versione XRD puo' essere `referenceable: true`. Il valore
`apiVersion` deve essere coerente in XRD, `compositeTypeRef` e XR.

### Soluzione Q5

La struttura minima e':

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

Le patch da XR a Namespace e ConfigMap usano
`type: FromCompositeFieldPath`.

### Soluzione Q6

Per label e annotation con `/` usa i path tra parentesi:

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

### Soluzione Q7

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

### Soluzione Q8

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

### Soluzione Q9

```yaml
- type: FromCompositeFieldPath
  fromFieldPath: spec.accountTier
  toFieldPath: data.size
  transforms:
    - type: map
      map:
        dev: small
        prod: large
```

### Soluzione Q10

Definisci `patchSets` nell'input `Resources`, poi richiamalo con:

```yaml
- type: PatchSet
  patchSetName: common-metadata
```

### Soluzione Q11

```yaml
- type: ToCompositeFieldPath
  fromFieldPath: metadata.name
  toFieldPath: status.namespace
- type: ToCompositeFieldPath
  fromFieldPath: metadata.annotations[platform.example.com/domain]
  toFieldPath: status.observedDomain
```

I campi destinazione devono esistere nello schema XRD.

### Soluzione Q12

```yaml
readinessChecks:
  - type: MatchString
    fieldPath: data.ready
    matchString: "true"
```

### Soluzione Q13

Il selector dell'XR deve corrispondere alle label della Composition:

```bash
kubectl get dataspace analytics \
  -o jsonpath='{.spec.crossplane.compositionRef.name}{"\n"}'
kubectl get dataspace analytics \
  -o jsonpath='{.spec.crossplane.compositionRevisionRef.name}{"\n"}'
```

### Soluzione Q14

Sostituisci `function-does-not-exist` con
`function-patch-and-transform`, aggiungi una base Namespace valida e
riapplica. Controlla:

```bash
kubectl get functions
kubectl describe securityspace
kubectl get events -A --sort-by=.lastTimestamp
```

### Soluzione Q15

La policy predefinita e' `Automatic`: una modifica alla Composition genera
una nuova CompositionRevision che viene adottata dall'XR.

```bash
kubectl get compositionrevisions \
  -l crossplane.io/composition-name=compliance-composition
```

### Soluzione Q16

Con policy `Manual`, recupera la nuova revisione e impostala nell'XR:

```bash
kubectl patch runtimespace java-services --type=merge -p \
  '{"spec":{"crossplane":{"compositionRevisionRef":{"name":"REVISIONE"}}}}'
```

### Soluzione Q17

```bash
kubectl patch releasespace canary --type=merge -p \
  '{"spec":{"releaseChannel":"stable"}}'
kubectl get releasespace canary -o jsonpath='{.metadata.uid}{"\n"}'
```

Confronta UID e valori delle risorse prima e dopo la patch.

### Soluzione Q18

```bash
kubectl -n exam annotate observabilityspace sre-tools \
  crossplane.io/paused=true
kubectl -n exam annotate observabilityspace sre-tools \
  crossplane.io/paused-
```

### Soluzione Q19

Allinea XRD e `compositeTypeRef`, correggi il `fromFieldPath` e aggiungi
`spec.backupPolicy` all'XR. Diagnostica in quest'ordine:

```bash
kubectl get xrd,composition
kubectl describe composition backup-composition
kubectl describe backupspace critical-backups
kubectl get events -A --sort-by=.lastTimestamp
```

### Soluzione Q20

Combina i costrutti delle prove Q1, Q3, Q5, Q11 e Q12. Controllo finale:

```bash
kubectl wait --for=condition=Established \
  xrd/platformspaces.platform.example.com
kubectl wait --for=condition=Healthy \
  function/function-patch-and-transform
kubectl get platformspace developer-portal -o yaml
kubectl get ns developer-portal
kubectl -n developer-portal get cm platform-config -o yaml
kubectl describe platformspace developer-portal
```
