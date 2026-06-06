# Crossplane Lab - 20 domande

File: `~/course-crossplane`. Namespace XR: `platform-team`.

### Q1 - XRD namespaced
Completa `01/xrd.yaml`: XRD v2 namespaced `App`, plural `apps`, gruppo
`platform.example.io`, versione `v1alpha1` served/referenceable.

### Q2 - Schema XRD
Aggiungi spec required: `image` string, `replicas` integer 1..10,
`environment` enum dev/staging/prod. `valid.yaml` accettato, `invalid.yaml`
rifiutato.

### Q3 - Default e status
Imposta default replicas 1 e aggiungi status `url` string e `readyReplicas`
integer. Verifica la CRD generata.

### Q4 - Prima Composition
Completa `04/composition.yaml` pipeline con function-patch-and-transform e
ConfigMap `app-config` nel Namespace dell'XR.

### Q5 - FromComposite patches
Patcha `spec.image`, `spec.replicas`, `spec.environment` nei data del
ConfigMap e `metadata.namespace` nei metadata.

### Q6 - Composed Deployment
Aggiungi Deployment `app` con label/selector `app=<XR name>`, immagine e
repliche dalla spec, Namespace dell'XR. L'XR `demo` deve creare due risorse.

### Q7 - Composed Service
Aggiungi Service `app` ClusterIP porta 80 target 8080, selector derivato dal
nome XR. Verifica le tre resource references.

### Q8 - String combine
Usa `CombineFromComposite` per creare annotation
`platform.example.io/identity=<namespace>-<name>` sul Deployment.

### Q9 - Map transform
Trasforma environment in log level: dev=debug, staging=info, prod=warn,
scrivendo `data.logLevel` nel ConfigMap.

### Q10 - Math transform
Moltiplica `spec.replicas` per 2 e scrivi il risultato in
`data.maxConnections` come stringa.

### Q11 - Patch policy Required
Rendi required la patch `spec.image`. Applica `missing-image.yaml` e salva
l'errore di reconcile in `11/result.txt`.

### Q12 - ToComposite status
Patcha `status.readyReplicas` dallo status del Deployment e componi
`status.url` come `http://<name>.<namespace>.svc`.

### Q13 - Readiness checks
Configura Deployment ready quando condizione Available=True, Service con
readiness `None`, ConfigMap con `MatchString data.ready=true`.

### Q14 - Composition selection
Crea Composition `app-development` e `app-production` con label
`tier=development|production`. In `14/xr.yaml` seleziona production tramite
`compositionSelector.matchLabels`.

### Q15 - Composition revisions
Imposta `defaultCompositionUpdatePolicy: Manual` nell'XRD. Aggiorna la
Composition aggiungendo label `revision=v2`, poi porta l'XR alla nuova
CompositionRevision esplicitamente.

### Q16 - EnvironmentConfig
Crea `EnvironmentConfig` `platform-defaults` con `region=eu-west` e
`owner=platform`; patcha entrambi come annotation del Deployment.

### Q17 - Patch sets
Definisci patchSet `common-metadata` con Namespace e label team, poi riusalo
su ConfigMap, Deployment e Service senza duplicare le patch.

### Q18 - Function pipeline
Aggiungi un secondo step `function-auto-ready` dopo patch-and-transform.
Installa la Function indicata in `18/function.yaml` e verifica le Function
Healthy.

### Q19 - Troubleshooting
`19` contiene XRD, Composition e XR con quattro errori: kind mismatch, field
path errato, functionRef errata e schema non strutturale. Correggili e compila
`19/report.md` con eventi e condizioni prima/dopo.

### Q20 - Simulazione a tempo
In 30 minuti crea API `WebService` con image, replicas, port e environment;
Composition con ConfigMap, Deployment e Service; map transform log level,
status URL, readiness e patchSet metadata. `20/xr.yaml` deve diventare Ready.
