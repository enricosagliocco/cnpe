# CNPE Capacity and Autoscaling Lab

Scenario creato da `setup-capacity-autoscaling-lab.sh`. Gli starter sono in
`~/course-capacity-autoscaling/`.

## Vincolo d'esame

**Non modificare i Deployment installati dal setup.** Non usare `kubectl edit`,
`kubectl patch`, `kubectl set resources` o `kubectl scale` sui workload.

Puoi modificare esclusivamente:

- ResourceQuota;
- LimitRange;
- VerticalPodAutoscaler;
- HorizontalPodAutoscaler;
- ScaledObject KEDA;
- Pod di test e generatori di carico forniti.

Non modificare o disinstallare Metrics Server, VPA o KEDA.

---

### Q1 – ResourceQuota e Pod mancanti

Nel Namespace `quota-lab`, il Deployment `quota-api` richiede due repliche ma
non riesce a renderle entrambe disponibili.

1. Analizza Deployment, ReplicaSet, eventi e stato della ResourceQuota.
2. Spiega in `01/diagnosi.txt` perché una replica viene negata.
3. Correggi soltanto `01/resourcequota.yaml` impostando:
   - `requests.cpu: "1"`;
   - `requests.memory: 1Gi`;
   - `limits.cpu: "2"`;
   - `limits.memory: 2Gi`;
   - `pods: "5"`.
4. Applica la quota senza modificare o riavviare il Deployment.
5. Verifica che il controller crei automaticamente la replica mancante e che
   il Deployment diventi disponibile `2/2`.
6. Salva utilizzo e limiti finali della quota in `01/diagnosi.txt`.

---

### Q2 – LimitRange e default eccessivi

Il Pod `defaults-demo` non viene creato nel Namespace `limits-lab`. Il suo
manifest non specifica risorse e non deve essere modificato.

1. Riproduci il rifiuto applicando `02/pod.yaml`.
2. Confronta LimitRange e ResourceQuota presenti nel Namespace.
3. Correggi soltanto `02/limitrange.yaml`:
   - default request CPU `100m`;
   - default request memory `128Mi`;
   - default limit CPU `500m`;
   - default limit memory `512Mi`;
   - massimo CPU `1`;
   - massimo memory `1Gi`.
4. Applica il LimitRange e quindi `02/pod.yaml`.
5. Verifica nello spec del Pod ammesso che request e limit siano stati
   aggiunti automaticamente.
6. Salva errore iniziale e risorse finali in `02/diagnosi.txt`.

---

### Q3 – VPA senza raccomandazioni

Il VPA `recommendation-api` esiste ma non produce raccomandazioni per il
Deployment nel Namespace `vpa-lab`.

1. Analizza `TargetRef`, condizioni ed eventi del VPA.
2. Correggi soltanto `03/vpa.yaml` affinché punti al Deployment
   `recommendation-api`.
3. Mantieni `updateMode: "Off"`: il VPA deve osservare e raccomandare, senza
   cambiare o ricreare i Pod.
4. Mantieni i limiti minimi e massimi già presenti per CPU e memoria.
5. Attendi che `.status.recommendation.containerRecommendations` sia
   valorizzato.
6. Salva in `03/recommendation.txt` target, lower bound, recommendation,
   upper bound e uncapped target.

---

### Q4 – HPA CPU non funzionante

Nel Namespace `hpa-lab` il Deployment `hpa-api` è pronto, ma lo starter HPA
non può scalarlo correttamente.

1. Verifica che Metrics Server esponga metriche per il Pod.
2. Correggi `04/hpa.yaml`:
   - target Deployment `hpa-api`;
   - minimo `1`;
   - massimo `5`;
   - utilizzo CPU medio target `50`.
3. Applica l'HPA e verifica che il target non sia `<unknown>`.
4. Applica `04/load-generator.yaml`.
5. Osserva HPA e Deployment finché il numero di repliche supera `1`.
6. Elimina il Pod `load-generator` e osserva il successivo scale down.
7. Salva in `04/result.txt` metriche, condizioni HPA e numero massimo di
   repliche osservato.

Non associare un VPA CPU allo stesso Deployment.

---

### Q5 – KEDA e HPA generato

Il Deployment `queue-worker` nel Namespace `keda-lab` parte da zero repliche.
Lo ScaledObject starter non controlla il target corretto.

1. Analizza errori, condizioni e target dello ScaledObject.
2. Correggi soltanto `05/scaledobject.yaml` affinché controlli
   `queue-worker`.
3. Mantieni:
   - minimo `0`;
   - massimo `4`;
   - cron timezone `Europe/Rome`;
   - finestra giornaliera `00:00`–`23:59`;
   - `desiredReplicas: "3"`.
4. Applica lo ScaledObject e verifica condizioni `Ready=True` e
   `Active=True`.
5. Identifica l'HPA creato e gestito da KEDA.
6. Verifica che il Deployment raggiunga tre repliche durante la finestra.
7. Salva ScaledObject, HPA generato e Deployment in `05/status.txt`.

Non creare manualmente un secondo HPA per `queue-worker`.

---

### Verifica finale

```bash
kubectl -n quota-lab get resourcequota,deploy,pods
kubectl -n limits-lab get limitrange,resourcequota,pod
kubectl -n vpa-lab get vpa,deploy,pods
kubectl -n hpa-lab get hpa,deploy,pods
kubectl -n keda-lab get scaledobject,hpa,deploy,pods
```

La prova è completa quando tutti e cinque gli esercizi soddisfano i risultati
richiesti senza modifiche ai Deployment.
