# Le 20 domande dell'esame - Flagger Lab

Scenario creato da `setup-flagger-lab.sh`. Manifest e file starter sono in
`~/course-flagger/`. Le risorse applicative devono risiedere nel Namespace
`flagger-lab`.

**Vincolo:** non modificare il Deployment del controller Flagger o le CRD.
Gli aggiornamenti applicativi devono essere gestiti dalla risorsa `Canary`;
non modificare direttamente i workload `*-primary` generati da Flagger.

---

### Q1 - Canary base

Completa `01/canary.yaml` con provider `kubernetes`, target Deployment
`podinfo`, Service sulla porta 9898 e analisi ogni 10 secondi. Applica e
verifica la creazione di `podinfo-primary` e dei Service gestiti.

### Q2 - Target reference

`02/canary.yaml` contiene un target errato. Correggi apiVersion, kind e name,
poi verifica `Initialized=True` e gli owner reference delle risorse generate.

### Q3 - Service configuration

Configura porta, targetPort, port discovery e timeout del Service in
`03/canary.yaml`. Verifica i Service `podinfo`, `podinfo-primary` e
`podinfo-canary`.

### Q4 - Analysis interval

Imposta intervallo 10s, threshold 3, maxWeight 50 e stepWeight 10. Avvia un
update dell'immagine e salva la progressione degli eventi in `04/evidence.txt`.
Spiega perché il provider Kubernetes usa le iterazioni ma non effettua traffic
shifting percentuale.

### Q5 - Iterations

Con provider Kubernetes, configura cinque iterazioni di analisi prima della
promozione. Verifica durata, stato e revisione promossa.

### Q6 - Successful promotion

Applica il canary in `06/`, aggiorna `podinfo` da `6.9.1` a `6.9.2` e verifica
promozione, scale-down del canary e aggiornamento del primary.

### Q7 - Failed rollout

Avvia una revisione con immagine inesistente. Verifica rollback automatico,
incremento dei failed checks e continuità del primary. Salva le prove.

### Q8 - Built-in metrics

Completa le metriche `request-success-rate` e `request-duration` con soglie
99% e 500ms. Identifica il requisito del metrics server e verifica le
condizioni mostrate da Flagger.

### Q9 - MetricTemplate

Completa `09/metric-template.yaml` con query Prometheus parametrica e collega
il template al Canary. Verifica gli argomenti renderizzati.

### Q10 - Custom metric thresholds

Passa `service`, `namespace` e una soglia dal Canary al MetricTemplate.
Configura interval e thresholdRange e documenta success/failure.

### Q11 - Pre-rollout webhook

Completa il webhook `pre-rollout` affinché chiami il load tester e blocchi
l'avanzamento in caso di errore HTTP.

### Q12 - Rollout webhook

Configura un webhook `rollout` che generi traffico verso
`podinfo-canary:9898` durante ogni iterazione.

### Q13 - Confirm promotion

Aggiungi un webhook `confirm-promotion` con timeout 30s. Usa il servizio gate
fornito e verifica che la promozione attenda una risposta positiva.

### Q14 - Post-rollout webhook

Configura il webhook finale per registrare stato e revisioni dopo promozione
o rollback. Salva payload ed eventi in `14/evidence.txt`.

### Q15 - AlertProvider

Completa `15/alert-provider.yaml` e collega alert di severità `info` e
`error` al Canary. Usa il receiver locale senza inserire credenziali nei log.

### Q16 - Blue/green

Configura una strategia blue/green con `stepWeight: 100`, iterazioni, gate di
conferma e rollback automatico. Verifica Service primary/canary.

### Q17 - A/B testing

Completa il routing HTTP A/B basato sull'header `x-canary: insider`. Indica
quale provider di routing è richiesto e valida il manifest lato client.

### Q18 - Gateway API e ingress

Completa `18/canary.yaml` e `httproute.yaml` per Gateway API. Documenta le
differenze rispetto ai provider NGINX e Istio in `18/evidence.txt`.

### Q19 - Troubleshooting

`19/canary.yaml` contiene target, Service e analisi incoerenti. Riproduci il
fallimento, correggilo e salva condizioni, eventi, causa e fix in
`19/report.md`.

### Q20 - Simulazione a tempo

Completa una progressive delivery con Deployment, Canary, metric template,
load webhook, promotion gate e alert. Esegui una promozione e un rollback:

```bash
kubectl -n flagger-lab get canaries,deployments,services,metrictemplates,alertproviders
kubectl -n flagger-lab describe canary final-api
kubectl -n flagger-lab get events --sort-by=.lastTimestamp
```

Salva timeline, revisioni, metriche e disponibilità in `20/final-report.md`.
