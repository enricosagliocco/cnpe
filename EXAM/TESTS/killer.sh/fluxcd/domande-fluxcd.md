# Lab FluxCD – Domande d'esame (versione standalone)

Queste domande coprono i topic FluxCD più rilevanti e difficili che compaiono nelle certificazioni
GitOps/CNPE: riconciliazione con Kustomization, HelmRelease, Image Automation, OCI, Notification,
multi-tenant, drift e dependency ordering.

---

## Q1 – Riprendi la Kustomization sospesa e correggi il drift

La Kustomization `havel-west` in `flux-system` è sospesa (`suspend: true`).  
Durante la sospensione, qualcuno ha applicato modifiche manuali al cluster:

- Il Deployment `logger` nel Namespace `havel-west` è stato scalato a 2 repliche (il Git dice 1)
- Il ConfigMap `logger-config` ha `log-level: debug` (il Git dice `info`)

**Task:**

1. Riprendi la Kustomization `havel-west` usando la `flux` CLI
2. Forza una riconciliazione immediata senza aspettare l'intervallo
3. Verifica che il drift sia stato corretto (le risorse tornino allo stato del repository)
4. Scrivi l'output di `flux get kustomization havel-west` in `/course/flux/q1-status.txt`

---

## Q2 – Crea GitRepository e Kustomization per havel-east

Il repository `/course/flux/havel-east` contiene manifest Kubernetes (StatefulSet + Secrets).  
È già stato pushato su Gitea all'URL `http://192.168.100.21:3000/projects/havel-east.git`, branch `main`.

**Task:**

1. Crea la risorsa `GitRepository` chiamata `havel-east` in `flux-system`:
   - URL: `http://192.168.100.21:3000/projects/havel-east.git`
   - Branch: `main`
   - Intervallo di polling: `1m`
2. Crea la risorsa `Kustomization` chiamata `havel-east` in `flux-system`:
   - Sorgente: `GitRepository/havel-east`
   - Path: `./`
   - `targetNamespace: havel-east`
   - `prune: true`
   - Intervallo: `5m`
3. Verifica che la Kustomization raggiunga lo stato `Ready=True`

---

## Q3 – HelmRelease con HelmRepository (podinfo)

**Task:**

1. Crea un `HelmRepository` chiamato `podinfo` in `flux-system` che punta a `https://stefanprodan.github.io/podinfo`
2. Crea un `HelmRelease` chiamato `podinfo` nel Namespace `caribbean` che:
   - Usa il chart `podinfo` versione `>=6.0.0 <7.0.0` dal `HelmRepository` appena creato
   - Imposta il valore Helm `replicaCount: 2`
   - Abilita la strategia di `remediation` su upgrade fallito: `retries: 3`
3. Verifica che il release sia in stato `Ready=True`
4. Aggiorna il `HelmRelease` per portare `replicaCount` a `3` **senza toccare il HelmRepository**  
   e verifica che Flux applichi l'upgrade automaticamente

---

## Q4 – HelmRelease con valori da ConfigMap e Secret

Nel Namespace `flux-system` esiste già un Secret `podinfo-secret` con una chiave `api-key`.

**Task:**

1. Modifica il `HelmRelease` `podinfo` del task precedente per iniettare valori da fonti esterne:
   - Aggiungi `valuesFrom` per leggere tutti i valori dal ConfigMap `podinfo-values` (crea anche il ConfigMap con `logLevel: "warn"`)
   - Aggiungi `valuesFrom` per leggere la chiave `api-key` dal Secret `podinfo-secret` e mapparla al valore Helm `auth.apiKey`
2. Riconcilia e verifica che i valori siano stati applicati correttamente al Deployment

---

## Q5 – Dependency ordering tra Kustomization

Hai due Kustomization: `infra-certs` e `infra-ingress`.  
`infra-ingress` deve essere riconciliata **solo dopo** che `infra-certs` è `Ready`.

**Task:**

1. Le Kustomization di base sono già in `/course/flux/q5/`. Applicale al cluster
2. Aggiungi a `infra-ingress` il campo `dependsOn` che la fa aspettare `infra-certs`
3. Simula un fallimento sospendendo `infra-certs` e osserva lo stato di `infra-ingress`  
   (scrivi il messaggio di status in `/course/flux/q5-dependency.txt`)
4. Riprendi `infra-certs` e verifica che `infra-ingress` torni `Ready`

---

## Q6 – Image Automation: aggiorna automaticamente il tag dell'immagine

Il Deployment `havel-west/logger` usa l'immagine `busybox:1.36`.  
Vuoi che Flux aggiorni automaticamente il tag quando una nuova immagine `busybox:1.*` viene rilasciata.

**Task:**

1. Crea un `ImageRepository` chiamato `busybox` in `flux-system` che osserva `docker.io/library/busybox`
2. Crea un `ImagePolicy` chiamata `busybox` in `flux-system`:
   - Usa il semver filter `1.x` (solo tag patch della serie 1)
3. Annota il manifest `deployment.yaml` di `havel-west` per indicare a Flux quale campo aggiornare:
   ```yaml
   # {"$imagepolicy": "flux-system:busybox"}
   ```
4. Crea un `ImageUpdateAutomation` chiamato `havel-west` in `flux-system` che:
   - Committi le modifiche sull'immagine nel repository Git `havel-west`
   - Usa il messaggio di commit `"chore: update busybox tag to {{range .Updated.Images}}{{.}}{{end}}"`
5. Verifica con `flux get image all -n flux-system` che le risorse siano Ready

---

## Q7 – OCI Repository: deploy da registry OCI

Un chart Helm è stato pushato come OCI artifact su `oci://ghcr.io/stefanprodan/charts/podinfo`.

**Task:**

1. Crea un `OCIRepository` chiamato `podinfo-oci` in `flux-system`:
   - URL: `oci://ghcr.io/stefanprodan/charts/podinfo`
   - Tag: `6.7.0`
   - Tipo: `chart` (`spec.layerSelector.mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip`)
2. Crea un `HelmRelease` chiamato `podinfo-oci` nel Namespace `caribbean` che usa `OCIRepository/podinfo-oci` come source
3. Verifica che il release sia `Ready` e che il chart sia stato installato

---

## Q8 – Notifiche: Alert su fallimento di Kustomization

Vuoi ricevere notifiche via webhook quando una Kustomization fallisce.

**Task:**

1. Crea un `Provider` chiamato `generic-webhook` in `flux-system` di tipo `generic`  
   che punta a `http://webhook-receiver.flux-system.svc.cluster.local/hook`
2. Crea un `Alert` chiamato `kustomization-failures` in `flux-system` che:
   - Usa il Provider appena creato
   - Si attiva per gli eventi di severity `error`
   - Filtra gli eventi sull'`eventSource` di tipo `Kustomization` (tutte le Kustomization nel namespace `flux-system`)
3. Verifica con `flux get alert -n flux-system` che l'Alert sia `Ready`

---

## Q9 – Receiver: webhook Git per riconciliazione immediata

Invece di attendere il polling interval, vuoi che Gitea triggheri Flux via webhook HTTP.

**Task:**

1. Crea un `Receiver` chiamato `gitea-receiver` in `flux-system` di tipo `generic`:
   - Genera un Secret chiamato `gitea-webhook-token` con un token casuale (usa `flux create secret generic`)
   - Configura il Receiver per riconciliare `GitRepository/havel-west` alla ricezione del webhook
2. Esponi il Receiver come NodePort `30095` (crea il Service necessario)
3. Recupera l'URL endpoint del Receiver e salvalo in `/course/flux/q9-receiver-url.txt`
4. Verifica che una chiamata `curl -X POST` all'URL con il token corretto trigghi la riconciliazione

---

## Q10 – Multi-tenant: Kustomization con ServiceAccount dedicato

In un setup multi-tenant, ogni team deve riconciliare **solo** le proprie risorse  
usando il principio del minimo privilegio.

**Task:**

1. Crea un `ServiceAccount` chiamato `havel-east-reconciler` nel Namespace `havel-east`
2. Crea un `Role` che permette solo `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`  
   su `deployments`, `services`, `configmaps`, `statefulsets` nel Namespace `havel-east`
3. Associa il Role al ServiceAccount con un `RoleBinding`
4. Modifica la Kustomization `havel-east` per usare questo ServiceAccount:
   ```yaml
   spec:
     serviceAccountName: havel-east-reconciler
   ```
5. Forza una riconciliazione e verifica che le risorse vengano ancora deployate correttamente

---

## Q11 – Diagnosi: Kustomization bloccata su "health check timeout"

La Kustomization `havel-east` è in stato `False` con messaggio "health check timeout".

**Task:**

1. Usa `flux get kustomization havel-east -n flux-system` per vedere lo status
2. Usa `flux events -n flux-system --for Kustomization/havel-east` per investigare
3. Identifica la risorsa non healthy (il StatefulSet `cache` ha un `readinessProbe` sbagliato in `/course/flux/q11/statefulset.yaml`)
4. Correggi il manifest, fai commit e push, poi forza riconciliazione
5. Verifica che la Kustomization torni `Ready=True`

---

## Q12 – Kustomize patches inline in Kustomization Flux

Vuoi fare patch a un manifest **senza modificare il repository sorgente**,  
usando la funzionalità `patches` direttamente nella risorsa `Kustomization` di Flux.

**Task:**

La Kustomization `havel-west` deploya il Deployment `logger` con `replicas: 1`.  
Aggiungi un patch strategico inline alla Kustomization Flux per impostare `replicas: 3`,  
senza modificare il file `deployment.yaml` nel repository Git.

```yaml
spec:
  patches:
    - patch: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: logger
        spec:
          replicas: 3
      target:
        kind: Deployment
        name: logger
```

Verifica che dopo la riconciliazione il Deployment abbia 3 repliche.

---

## Riferimenti rapidi – comandi utili

```bash
# Status di tutte le risorse Flux
flux get all -n flux-system

# Forza riconciliazione immediata
flux reconcile kustomization <name> -n flux-system --with-source

# Resume/Suspend
flux resume kustomization <name> -n flux-system
flux suspend kustomization <name> -n flux-system

# Log controller
kubectl -n flux-system logs deploy/kustomize-controller -f
kubectl -n flux-system logs deploy/helm-controller -f
kubectl -n flux-system logs deploy/source-controller -f

# Eventi su una risorsa
flux events -n flux-system --for Kustomization/<name>
flux events -n flux-system --for HelmRelease/<name>

# Esporta risorsa esistente
flux export kustomization <name>
flux export source git <name>
```
