# Le 20 domande dell'esame - Flagger Lab (simulatore lab)

Scenario creato da `setup-flagger-lab.sh`. Manifest e file starter si trovano
in `~/course-flagger/`. Le risorse applicative devono risiedere nel Namespace
`flagger-lab`.

Vincoli:

- Non modificare il Deployment del controller Flagger o le CRD.
- Gestire gli aggiornamenti applicativi tramite la risorsa `Canary`.
- Non modificare direttamente i workload `*-primary` generati da Flagger.
- Conservare i nomi delle risorse indicati nei file starter.
- Verificare ogni rollout tramite stato del Canary, eventi e risorse generate.

Le domande sono indipendenti. Prima di iniziare una domanda, elimina le risorse
Flagger create per quella precedente quando possono interferire con i test.
Gli esercizi con provider NGINX, Istio o Gateway API richiedono la validazione
dei manifest, ma il setup non installa automaticamente tutti i provider di
routing.

Comandi utili:

```bash
kubectl -n flagger-lab get canaries,deployments,services
kubectl -n flagger-lab describe canary <nome>
kubectl -n flagger-lab get events --sort-by=.lastTimestamp
kubectl -n flagger-system logs deploy/flagger -f
kubectl -n flagger-system logs deploy/flagger-loadtester
```

---

### Q1 - Canary base

Percorso: `~/course-flagger/01`.

Completa `canary.yaml`:

1. Imposta il provider `kubernetes`.
2. Configura `targetRef` per il Deployment `podinfo`.
3. Esponi il Service sulla porta `9898`.
4. Imposta l'intervallo di analisi a `10s`.
5. Applica `deployment.yaml` e `canary.yaml`.
6. Verifica la creazione del Deployment `podinfo-primary` e dei Service
   gestiti da Flagger.

---

### Q2 - Target reference

Percorso: `~/course-flagger/02`.

`canary.yaml` contiene un target errato.

1. Correggi `apiVersion`, `kind` e `name` di `targetRef`.
2. Applica il Deployment e il Canary.
3. Verifica che la condizione `Initialized` sia `True`.
4. Controlla gli owner reference delle risorse generate da Flagger.

---

### Q3 - Configurazione del Service

Percorso: `~/course-flagger/03`.

Correggi la sezione `service` di `canary.yaml`:

1. Imposta `port` e `targetPort` coerenti con il Deployment.
2. Abilita la port discovery.
3. Configura un timeout valido.
4. Applica le risorse.
5. Verifica configurazione ed endpoint dei Service `podinfo`,
   `podinfo-primary` e `podinfo-canary`.

---

### Q4 - Intervallo e progressione

Percorso: `~/course-flagger/04`.

1. Imposta `interval: 10s`.
2. Imposta `threshold: 3` e cinque iterazioni.
3. Avvia un aggiornamento dell'immagine del Deployment.
4. Salva in `evidence.txt` la progressione osservata negli eventi e nello
   stato del Canary.
5. Spiega nello stesso file perché il provider Kubernetes usa `iterations`
   invece di `maxWeight` e `stepWeight` e non effettua traffic shifting
   percentuale.

---

### Q5 - Iterazioni di analisi

Percorso: `~/course-flagger/05`.

1. Configura cinque iterazioni di analisi prima della promozione.
2. Applica Deployment e Canary.
3. Avvia una nuova revisione dell'immagine.
4. Verifica il numero di iterazioni, la durata del rollout e lo stato finale.
5. Controlla che la revisione promossa sia stata copiata nel primary.

---

### Q6 - Promozione riuscita

Percorso: `~/course-flagger/06`.

1. Applica `deployment.yaml` e `canary.yaml`.
2. Attendi l'inizializzazione del Canary.
3. Aggiorna l'immagine `podinfo` da `6.9.1` a `6.9.2`.
4. Verifica la promozione della nuova revisione.
5. Verifica lo scale-down del canary e l'aggiornamento del primary.
6. Salva stato, revisioni ed eventi principali in `evidence.txt`.

---

### Q7 - Rollout fallito

Percorso: `~/course-flagger/07`.

1. Applica lo scenario e attendi l'inizializzazione.
2. Avvia una revisione usando un'immagine inesistente.
3. Verifica il rollback automatico e l'incremento dei failed checks.
4. Dimostra che il primary precedente resta disponibile.
5. Salva condizioni, eventi e immagini dei workload in `evidence.txt`.

---

### Q8 - Metriche integrate

Percorso: `~/course-flagger/08`.

Prima di proseguire, verifica o installa il Prometheus incluso nel chart di
Flagger:

```bash
helm repo add flagger https://flagger.app
helm repo update flagger
helm upgrade --install flagger flagger/flagger \
  --version 1.43.0 \
  --namespace flagger-system \
  --create-namespace \
  --reuse-values \
  --set meshProvider=kubernetes \
  --set prometheus.install=true \
  --wait

kubectl -n flagger-system rollout status deployment/flagger-prometheus
kubectl -n flagger-system get deployment,service flagger-prometheus
```

Il setup del laboratorio esegue già questa installazione; il comando è
idempotente e assicura che Prometheus sia presente e abilitato.

In un terminale separato, esponi l'interfaccia di Prometheus su tutte le
interfacce di rete dell'host:

```bash
kubectl -n flagger-system port-forward \
  --address 0.0.0.0 service/flagger-prometheus 9090:9090
```

Apri `http://localhost:9090/targets` dalla macchina locale oppure
`http://<IP-host>:9090/targets` da un'altra macchina autorizzata dalla
configurazione di rete e dal firewall.

Completa quindi `analysis.metrics`:

1. Aggiungi `request-success-rate` con soglia minima `99`.
2. Aggiungi `request-duration` con soglia massima `500` millisecondi.
3. Applica `deployment.yaml` e `canary.yaml`.
4. Avvia una nuova revisione.
5. Verifica le metriche durante il traffico generato dal webhook e documenta
   le condizioni mostrate da Flagger.

Comandi di applicazione e avvio della revisione:

```bash
cd ~/course-flagger/08
kubectl apply -f deployment.yaml
kubectl apply -f canary.yaml
kubectl -n flagger-lab wait \
  --for=condition=Initialized canary/podinfo \
  --timeout=120s
kubectl -n flagger-lab set image deployment/podinfo \
  podinfo=ghcr.io/stefanprodan/podinfo:6.9.2
```

Per verificare esposizione e raccolta delle metriche, crea un pod di test:

```bash
kubectl -n flagger-lab run metrics-test \
  --image=curlimages/curl:8.12.1 \
  --restart=Never \
  --command -- sleep 3600

kubectl -n flagger-lab wait \
  --for=condition=Ready pod/metrics-test \
  --timeout=60s
```

Verifica prima che `podinfo` esponga direttamente le metriche:

```bash
kubectl -n flagger-lab exec metrics-test -- \
  curl -fsS http://podinfo:9898/metrics
```

Genera traffico applicativo:

```bash
kubectl -n flagger-lab exec metrics-test -- sh -c \
  'for i in $(seq 1 100); do curl -fsS http://podinfo:9898/ >/dev/null; done'
```

Attendi almeno un intervallo di scraping e interroga Prometheus dal pod:

```bash
kubectl -n flagger-lab exec metrics-test -- \
  curl -fsSG http://flagger-prometheus.flagger-system:9090/api/v1/query \
  --data-urlencode \
  'query=up{job="kubernetes-pods",kubernetes_namespace="flagger-lab",kubernetes_pod_name=~"podinfo.*"}'

kubectl -n flagger-lab exec metrics-test -- \
  curl -fsSG http://flagger-prometheus.flagger-system:9090/api/v1/query \
  --data-urlencode \
  'query=http_requests_total{kubernetes_namespace="flagger-lab",kubernetes_pod_name=~"podinfo.*"}'
```

La prima query deve restituire almeno una serie con valore `1`; la seconda
deve mostrare il contatore HTTP di `podinfo`. Durante la revisione ripeti il
test verso `http://podinfo-canary:9898/` e controlla condizioni ed eventi:

```bash
kubectl -n flagger-lab exec metrics-test -- sh -c \
  'for i in $(seq 1 100); do curl -fsS http://podinfo-canary:9898/ >/dev/null; done'

kubectl -n flagger-lab describe canary podinfo
kubectl -n flagger-lab get events --sort-by=.lastTimestamp
kubectl -n flagger-system logs deployment/flagger --tail=100
kubectl -n flagger-lab delete pod metrics-test
```

---

### Q9 - MetricTemplate

Percorso: `~/course-flagger/09`.

1. Completa `metric-template.yaml` con una query Prometheus parametrica.
2. Mantieni il nome `request-count`.
3. Collega il `MetricTemplate` alla metrica in `canary.yaml`.
4. Applica template, Deployment e Canary.
5. Verifica il riferimento al template e gli argomenti renderizzati da
   Flagger.

---

### Q10 - Soglie di una metrica custom

Percorso: `~/course-flagger/10`.

1. Completa il `MetricTemplate` per usare variabili parametrizzate.
2. Passa dal Canary `service`, `namespace` e una soglia.
3. Configura `interval` e `thresholdRange` della metrica.
4. Esegui un caso che soddisfa la soglia e uno che la viola.
5. Documenta risultato, failed checks e stato finale.

---

### Q11 - Webhook pre-rollout

Percorso: `~/course-flagger/11`.

Completa il webhook `pre-rollout-check`:

1. Usa il servizio `flagger-loadtester` nel Namespace `flagger-system`.
2. Configura URL, tipo e metadata richiesti dal load tester.
3. Avvia una revisione e verifica che il controllo venga eseguito prima
   dell'analisi.
4. Riproduci un errore HTTP del webhook.
5. Verifica che l'errore blocchi l'avanzamento del rollout.

---

### Q12 - Webhook rollout

Percorso: `~/course-flagger/12`.

1. Completa il comando del webhook `load-test`.
2. Genera traffico verso `podinfo-canary:9898`.
3. Avvia una nuova revisione.
4. Verifica che il webhook venga invocato durante ogni iterazione.
5. Controlla i log del load tester e gli eventi del Canary.

---

### Q13 - Conferma della promozione

Percorso: `~/course-flagger/13`.

1. Imposta il tipo del webhook a `confirm-promotion`.
2. Imposta il timeout a `30s`.
3. Usa il servizio gate già indicato nel file starter.
4. Avvia una revisione e verifica che la promozione attenda il gate.
5. Verifica che una risposta positiva consenta la promozione.

---

### Q14 - Webhook post-rollout

Percorso: `~/course-flagger/14`.

1. Configura un webhook di tipo `post-rollout`.
2. Usa `http://flagger-receiver.flagger-system/webhook`.
3. Esegui una promozione e un rollback.
4. Verifica che il webhook venga richiamato al termine di entrambi.
5. Recupera i payload dai log di `deployment/flagger-receiver` nel Namespace
   `flagger-system` e salvali con stato, revisioni ed eventi in
   `evidence.txt`.

---

### Q15 - AlertProvider

Percorso: `~/course-flagger/15`.

1. Completa `alert-provider.yaml` con tipo `slack` e address
   `http://flagger-receiver.flagger-system/slack`.
2. Non inserire credenziali direttamente nei log o nei manifest.
3. Collega al Canary un alert di severità `info`.
4. Collega al Canary un alert di severità `error`.
5. Esegui una promozione e un rollout fallito.
6. Verifica gli alert ricevuti per entrambi i casi.

---

### Q16 - Strategia blue/green

Percorso: `~/course-flagger/16`.

1. Configura tre iterazioni di analisi.
2. Aggiungi un gate `confirm-promotion`.
3. Esegui una promozione e verifica lo switch completo.
4. Riproduci un errore e verifica il rollback automatico.
5. Controlla i Service primary e canary durante entrambe le operazioni.
6. Spiega perché con il provider Kubernetes la strategia blue/green usa
   `iterations` e non `stepWeight`.

---

### Q17 - A/B testing

Percorso: `~/course-flagger/17`.

1. Completa `ingressRef` usando l'Ingress `podinfo` fornito.
2. Completa il routing HTTP basato sull'header `x-canary`.
3. Invia al canary le richieste con valore `insider`.
4. Valida `ingress.yaml` e `canary.yaml` lato client.
5. Documenta perché il test end-to-end richiede il provider NGINX e un
   ingress controller non installato dal setup.

---

### Q18 - Gateway API e HTTPRoute generato

Percorso: `~/course-flagger/18`.

1. Completa `gateway.yaml` con una `GatewayClass` disponibile nel cluster.
2. Completa `hosts` e `gatewayRefs` in `canary.yaml`.
3. Verifica che sia Flagger a generare l'`HTTPRoute` `podinfo`; non creare
   manualmente una route con lo stesso nome.
4. Se nel cluster sono presenti le CRD e un controller Gateway API
   compatibile, applica le risorse e verifica il traffic shifting.
5. In assenza dei prerequisiti, valida la struttura dei manifest e documenta
   in `evidence.txt` le differenze rispetto ai provider NGINX e Istio.

---

### Q19 - Troubleshooting

Percorso: `~/course-flagger/19`.

`canary.yaml` contiene target, Service e analisi incoerenti.

1. Applica il manifest iniziale e raccogli l'errore.
2. Correggi `targetRef`.
3. Correggi porta e target port del Service.
4. Correggi intervallo, threshold e iterazioni dell'analisi.
5. Applica il manifest corretto e verifica l'inizializzazione.
6. Salva condizioni, eventi, causa e correzione in `report.md`.

---

### Q20 - Simulazione a tempo finale

Percorso: `~/course-flagger/20`.

Completa una progressive delivery end-to-end:

1. Completa `metric-template.yaml` con provider e query.
2. Completa `alert-provider.yaml`.
3. Collega al Canary la metrica custom.
4. Aggiungi un webhook di load test e un gate di promozione.
5. Configura gli alert.
6. Applica tutte le risorse ed esegui una promozione riuscita.
7. Esegui una seconda revisione che provochi un rollback.
8. Verifica metriche su `flagger-prometheus` e alert nei log di
   `flagger-receiver`.
9. Raccogli le verifiche con:

```bash
kubectl -n flagger-lab get canaries,deployments,services,metrictemplates,alertproviders
kubectl -n flagger-lab describe canary final-api
kubectl -n flagger-lab get events --sort-by=.lastTimestamp
```

Salva timeline, revisioni, metriche, alert e disponibilità in
`final-report.md`.
