# HPA and KEDA Troubleshooting Lab - 20 exam-style tasks

Ogni domanda e una prova pratica autonoma. Esamina i file forniti, applica
le risorse richieste e verifica il risultato nel cluster. Le sezioni
`Tip` aiutano a individuare API, file e comandi utili; la sezione
`Solution` riporta il flusso operativo di applicazione e verifica.

Non modificare o disinstallare i componenti core installati dal setup.
Usa il kubeconfig corrente e conserva le evidenze richieste dalla domanda.

Per ogni domanda esegui `./create-resources.sh` quando presente e termina
con `./remove-resources.sh`. Non lasciare risorse di uno scenario attive
durante la prova successiva.

Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---
### Q1 - HPA senza CPU request

Percorso: `~/course-hpa-keda/q01`.

L'HPA `web` mostra una metrica CPU non disponibile e non scala. Individua la
relazione tra utilizzo percentuale e request, aggiungi la sola request
mancante al container e verifica metriche valide.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q01
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q2 - Target HPA inesistente

Percorso: `~/course-hpa-keda/q02`.

L'HPA non trova il workload da scalare. Correggi `scaleTargetRef` senza
rinominare il Deployment e verifica che `ScalingActive=True`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q02` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q02
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q3 - Tipo di target CPU errato

Percorso: `~/course-hpa-keda/q03`.

Il ticket richiede una soglia media del 60% della CPU richiesta, ma il
manifest usa un tipo di target incompatibile con il valore dichiarato.
Correggi la metrica e verifica l'output di `kubectl describe hpa`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q03` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q03
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q4 - Intervallo repliche non valido

Percorso: `~/course-hpa-keda/q04`.

L'API rifiuta `scenario.yaml`. Usa il messaggio di validazione per correggere
soltanto `minReplicas` e `maxReplicas`, mantenendo l'intervallo 2-6.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q04` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q04
./create-resources.sh
kubectl apply -f scenario.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q5 - Metrica memory senza request

Percorso: `~/course-hpa-keda/q05`.

L'HPA usa la memoria percentuale ma non riceve un valore valido. Aggiungi una
request memory appropriata e verifica che la metrica diventi disponibile.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q05` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q05
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q6 - HPA con metriche multiple

Percorso: `~/course-hpa-keda/q06`.

CPU e memoria devono entrambe concorrere alla decisione di scaling. Correggi
la seconda metrica, genera carico e dimostra che HPA sceglie il numero di
repliche più alto proposto dalle metriche.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q06` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q06
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q7 - Scale down troppo aggressivo

Percorso: `~/course-hpa-keda/q07`.

Configura `behavior.scaleDown` con finestra di stabilizzazione di 300 secondi
e una policy massima del 25% ogni 60 secondi. Non modificare lo scale up.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q07` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q07
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q8 - Limite massimo insufficiente

Percorso: `~/course-hpa-keda/q08`.

Sotto carico il Deployment si ferma a due repliche. Porta il massimo a sei,
mantieni il minimo a uno e verifica uno scale out oltre due repliche.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q08` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q08
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q9 - Campo replicas gestito da HPA

Percorso: `~/course-hpa-keda/q09`.

Il Deployment viene riapplicato continuamente con `replicas: 1` mentre HPA
prova a scalarlo. Rimuovi il drift dichiarativo dal workload, senza eliminare
l'HPA, e documenta chi gestisce la subresource `scale`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q09` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q09
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q10 - Verifica HPA end-to-end

Percorso: `~/course-hpa-keda/q10`.

Ripristina un HPA CPU completo con minimo 1, massimo 5 e target 50%. Genera
carico con `load-generator.yaml`, osserva scale out e successivo scale in.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q10` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q10
./create-resources.sh
kubectl apply -f load-generator.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q11 - ScaledObject con target errato

Percorso: `~/course-hpa-keda/q11`.

KEDA non crea l'HPA perché `scaleTargetRef` punta a un Deployment inesistente.
Correggi il nome e verifica condizioni `Ready` e `Active`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q11` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q11
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q12 - Intervallo KEDA incoerente

Percorso: `~/course-hpa-keda/q12`.

Correggi `minReplicaCount` e `maxReplicaCount` per consentire scale-to-zero e
un massimo di cinque repliche. Verifica lo stato inattivo dopo il cooldown.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q12` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q12
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q13 - Trigger cron con timezone errata

Percorso: `~/course-hpa-keda/q13`.

Lo ScaledObject cron non diventa Ready. Correggi la timezone usando un nome
IANA valido e conserva le espressioni cron esistenti.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q13` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q13
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q14 - Trigger cron senza desiredReplicas

Percorso: `~/course-hpa-keda/q14`.

Il trigger cron è incompleto. Configura tre repliche desiderate nella finestra
indicata e verifica l'HPA generato da KEDA.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q14` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q14
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q15 - Scaling sospeso

Percorso: `~/course-hpa-keda/q15`.

Il trigger è valido ma il workload non scala perché lo ScaledObject è in
pausa. Rimuovi soltanto l'annotazione responsabile e verifica la
riconciliazione.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q15` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q15
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q16 - Fallback non raggiungibile

Percorso: `~/course-hpa-keda/q16`.

Il Prometheus endpoint è intenzionalmente irraggiungibile. Configura fallback
dopo tre errori con quattro repliche e dimostra la condizione risultante.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q16` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q16
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q17 - Secret di autenticazione mancante

Percorso: `~/course-hpa-keda/q17`.

`TriggerAuthentication` riferisce una chiave Secret errata. Correggi il
riferimento senza inserire credenziali nello ScaledObject e verifica che
l'errore di autenticazione sparisca.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q17` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q17
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q18 - Indirizzo Prometheus errato

Percorso: `~/course-hpa-keda/q18`.

Il servizio `mock-prometheus` espone una API compatibile per il test, ma lo
scaler usa un DNS errato. Correggi `serverAddress` e verifica che la metrica
esterna sia leggibile.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q18` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q18
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q19 - Query Prometheus non scalare

Percorso: `~/course-hpa-keda/q19`.

La query configurata non restituisce il valore numerico previsto dal mock.
Correggi soltanto la query e verifica che il workload raggiunga due o più
repliche.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q19` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q19
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q20 - Conflitto tra HPA e KEDA

Percorso: `~/course-hpa-keda/q20`.

Un HPA manuale e lo ScaledObject controllano lo stesso Deployment. Elimina il
conflitto mantenendo KEDA come unico proprietario dell'autoscaling, poi
verifica un solo HPA e condizioni KEDA sane.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-hpa-keda/q20` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-hpa-keda/q20
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```
