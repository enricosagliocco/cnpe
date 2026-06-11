# Le 20 domande dell'esame — Crossplane Lab (simulatore lab)

## Metodo operativo obbligatorio

Ogni domanda e un ticket di troubleshooting. Devi:

1. riprodurre o osservare lo stato iniziale nel cluster;
2. raccogliere il sintomo tramite stato, condizioni, eventi, log o output del controller;
3. identificare e registrare la causa radice;
4. creare gli elementi mancanti o correggere le sole risorse coinvolte;
5. applicare la soluzione e verificarla con un test runtime positivo e, quando previsto, negativo.

La sola modifica del file, il solo dry-run client-side o una risposta teorica
non completano il ticket. Conserva comando, errore iniziale, correzione e
verifica finale nell'evidence file indicato dalla domanda.

Scenario deployato da `setup-crossplane-lab.sh`. Manifest e file starter in
`~/course-crossplane/`. Le risorse composite namespaced devono essere create
nel Namespace `platform-team`, salvo diversa indicazione.

**Vincolo:** non disinstallare Crossplane o le Function installate. Puoi
modificare XRD, Composition, XR, Function e risorse composte, ma non i
Deployment core nel Namespace `crossplane-system`.

Ogni domanda contiene una definizione incompleta o intenzionalmente guasta.
Le domande Q1–Q3 costruiscono progressivamente l'API `App`; il setup installa
anche una baseline valida della stessa API per consentire l'esecuzione
indipendente delle Composition Q4–Q18. Le domande Q4–Q18 sono progressive:
quando una domanda richiede risorse aggiunte in quella precedente, usa la
Composition corretta precedente come base. Ogni soluzione deve essere
applicata e verificata tramite condizioni dell'XR, resource references e
risorse composte.

Accesso GUI:
- Crossplane non include una dashboard web dedicata in questo lab.
- Usa Lens/OpenLens con il kubeconfig corrente e apri **Custom Resources** per
  XRD, Composition, XR, eventi e risorse composte.

```bash
kubectl config current-context
kubectl config view --minify --raw
```

Credenziali:
- Non servono credenziali aggiuntive rispetto al kubeconfig Kubernetes.

Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q1 – XRD namespaced
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/01`.


`01/xrd.yaml` contiene placeholder nei campi di identità dell'API.

1. Completa l'XRD v2 namespaced `App`, plural `apps`, gruppo
   `platform.example.io`, versione `v1alpha1` served/referenceable.
2. Applica il file.
3. Verifica CRD `apps.platform.example.io` Established e scope Namespaced.

---

### Q2 – Schema XRD
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/02`.


`02/xrd.yaml` definisce l'API, ma lo schema di `spec` è vuoto.

1. Aggiungi spec required: `image` string, `replicas` integer 1..10, `environment` enum dev/staging/prod.
2. Applica l'XRD.
3. Verifica `valid.yaml` accettato e `invalid.yaml` rifiutato dal server API.

---

### Q3 – Default e status
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/03`.


`03/xrd.yaml` ha lo schema spec, ma manca default e schema status.

1. Imposta default replicas 1 e aggiungi status `url` string e `readyReplicas` integer.
2. Applica l'XRD e crea una risorsa senza `replicas`.
3. Verifica il default nello spec ammesso e la presenza dei campi nella CRD.

---

### Q4 – Prima Composition
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/04`.


La Composition starter crea un ConfigMap senza Namespace e senza dati.

1. Completa `04/composition.yaml` usando
   `function-patch-and-transform`.
2. Crea ConfigMap `app-config` nel Namespace dell'XR.
3. Applica Composition e `04/xr.yaml`.
4. Verifica resource reference e ConfigMap in `platform-team`.

---

### Q5 – FromComposite patches
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/05`.


Il ConfigMap composto non riflette la spec dell'XR.

1. Patcha `spec.image`, `spec.replicas`, `spec.environment` nei data del ConfigMap e `metadata.namespace` nei metadata.
2. Applica Composition e XR.
3. Verifica i quattro campi nella risorsa composta.

---

### Q6 – Composed Deployment
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/06`.


La Composition crea soltanto il ConfigMap.

1. Aggiungi Deployment `app` con label/selector `app=<XR name>`, immagine e repliche dalla spec, Namespace dell'XR.
2. Applica Composition e XR.
3. Verifica due resource references, rollout riuscito, immagine e repliche.

---

### Q7 – Composed Service
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/07`.


L'app composta non è esposta da alcun Service.

1. Aggiungi Service `app` ClusterIP porta 80 target 8080, selector derivato dal nome XR.
2. Applica Composition e XR.
3. Verifica tre resource references e gli endpoint del Service.

---

### Q8 – String combine
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/08`.


Il Deployment composto non ha un'identità univoca leggibile.

1. Usa `CombineFromComposite` per creare annotation `platform.example.io/identity=<namespace>-<name>` sul Deployment.
2. Applica la Composition.
3. Verifica l'annotation sul Deployment composto.

---

### Q9 – Map transform
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/09`.


Il ConfigMap non contiene un log level derivato dall'ambiente.

1. Trasforma environment in log level: dev=debug, staging=info, prod=warn, scrivendo `data.logLevel` nel ConfigMap.
2. Esegui la prova con almeno due XR aventi environment diversi.
3. Verifica i valori nei ConfigMap composti.

---

### Q10 – Math transform
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/10`.


Il limite connessioni non viene calcolato dalla capacità richiesta.

1. Moltiplica `spec.replicas` per 2 e scrivi il risultato in `data.maxConnections` come stringa.
2. Applica XR con `replicas: 2`.
3. Verifica `data.maxConnections: "4"`.

---

### Q11 – Patch policy Required
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/11`.


`11/missing-image.yaml` omette `spec.image`, ma la patch attuale non è
obbligatoria.

1. Rendi required la patch `spec.image`.
2. Applica Composition e `missing-image.yaml`.
3. Verifica XR non Ready e messaggio di reconcile relativo al field path.
4. Salva condizioni ed eventi in `11/result.txt`.

---

### Q12 – ToComposite status
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/12`.


Lo status dell'XR non espone disponibilità o URL del workload composto.

1. Patcha `status.readyReplicas` dallo status del Deployment e componi `status.url` come `http://<name>.<namespace>.svc`.
2. Applica Composition e XR e attendi il rollout.
3. Verifica entrambi i campi nello status dell'XR.

---

### Q13 – Readiness checks
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/13`.


L'XR non attende correttamente tutte le risorse composte.

1. Configura Deployment ready quando condizione Available=True, Service con readiness `None`, ConfigMap con `MatchString data.ready=true`.
2. Applica Composition e XR.
3. Verifica XR non Ready prima del campo `data.ready`.
4. Imposta il campo e verifica `Ready=True`.

---

### Q14 – Composition selection
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/14`.


Due varianti di Composition devono essere selezionate tramite label.

1. Crea Composition `app-development` e `app-production` con label `tier=development|production`.
2. In `14/xr.yaml` seleziona production tramite `compositionSelector.matchLabels`.
3. Applica le risorse.
4. Verifica nello status dell'XR la Composition selezionata.

---

### Q15 – Composition revisions
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/15`.


L'XRD starter usa ancora la policy automatica di aggiornamento.

1. Imposta `defaultCompositionUpdatePolicy: Manual` nell'XRD.
2. Aggiorna la Composition aggiungendo label `revision=v2`, poi porta l'XR alla nuova CompositionRevision esplicitamente.
3. Verifica che prima del pin l'XR resti sulla revisione precedente e dopo il
   pin usi la nuova.

---

### Q16 – EnvironmentConfig
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/16`.


`16/environment.yaml` contiene i default, ma la Composition non li usa.

1. Applica `16/function.yaml` e attendi che `function-environment-configs`
   sia Healthy.
2. Crea `EnvironmentConfig` `platform-defaults` con `region=eu-west` e
   `owner=platform`.
3. Aggiungi come primo step della pipeline `function-environment-configs`,
   selezionando `platform-defaults` per riferimento.
4. Nel successivo step `function-patch-and-transform`, usa patch
   `FromEnvironmentFieldPath` per scrivere `region` e `owner` come annotation
   del Deployment.
5. Applica EnvironmentConfig, Composition e XR e verifica le annotation
   sulla risorsa composta.

---

### Q17 – Patch sets
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/17`.


Namespace e label team sono duplicati o mancanti nelle risorse composte.

1. Definisci patchSet `common-metadata` con Namespace e label team, poi riusalo su ConfigMap, Deployment e Service senza duplicare le patch.
2. Applica Composition e XR.
3. Verifica Namespace e label su tutte e tre le risorse.

---

### Q18 – Function pipeline
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/18`.


La Function `function-auto-ready` è dichiarata nel file, ma non è installata
né inserita nella pipeline.

1. Aggiungi un secondo step `function-auto-ready` dopo patch-and-transform.
2. Installa la Function indicata in `18/function.yaml` e verifica le Function Healthy.
3. Applica Composition e XR.
4. Verifica ordine degli step e XR `Ready=True`.

---

### Q19 – Troubleshooting
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/19`.


I tre file in `19/` contengono quattro errori indipendenti e devono fallire
prima della correzione.

1. `19` contiene XRD, Composition e XR con quattro errori: kind mismatch, field path errato, functionRef errata e schema non strutturale.
2. Correggili e compila `19/report.md` con eventi e condizioni prima/dopo.
3. Verifica XRD Established, Function risolta, XR Ready e ConfigMap composto.

---

### Q20 – Simulazione a tempo
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-crossplane/20`.


I file `20/xrd.yaml`, `20/composition.yaml` e `20/xr.yaml` costituiscono uno
scenario vuoto da implementare end-to-end.

1. In 30 minuti crea API `WebService` con image, replicas, port e environment; Composition con ConfigMap, Deployment e Service; map transform log level, status URL, readiness e patchSet metadata.
2. Applica tutti i file.
3. Verifica `20/xr.yaml` Ready, tre resource references, rollout disponibile,
   Service con endpoint e status URL valorizzato.
