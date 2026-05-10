# Guida CNPE con Backstage (Approccio Docs-First)

Questa guida e fatta per studiare in modo incrementale usando solo documentazione ufficiale e snippet da copiare, adattare e verificare. L'obiettivo non e imparare a memoria, ma imparare a navigare rapidamente le fonti giuste.

## Principio di studio (sempre)

1. Parti dal problema pratico.
2. Apri la pagina ufficiale Backstage relativa.
3. Copia lo snippet minimo funzionante.
4. Personalizza solo 1-2 campi per volta.
5. Verifica in UI/API.
6. Salva nel tuo "playbook" personale cosa hai cambiato e perche.

## Fonti ufficiali da tenere aperte

- Backstage Getting Started: https://backstage.io/docs/getting-started/
- Backstage Configuration: https://backstage.io/docs/conf/
- Catalog descriptor format: https://backstage.io/docs/features/software-catalog/descriptor-format
- Software Catalog docs: https://backstage.io/docs/features/software-catalog/
- Software Templates: https://backstage.io/docs/features/software-templates/
- Writing templates: https://backstage.io/docs/features/software-templates/writing-templates
- TechDocs: https://backstage.io/docs/features/techdocs/
- Kubernetes plugin docs: https://backstage.io/docs/features/kubernetes/
- Auth docs: https://backstage.io/docs/auth/
- Deployment overview: https://backstage.io/docs/deployment/
- Deploy with Docker: https://backstage.io/docs/deployment/docker
- Deploy with Kubernetes: https://backstage.io/docs/deployment/k8s

Per la parte CNCF generale, affianca sempre:
- Kubernetes docs: https://kubernetes.io/docs/
- Helm docs: https://helm.sh/docs/
- Prometheus docs: https://prometheus.io/docs/
- OpenTelemetry docs: https://opentelemetry.io/docs/

## Percorso incrementale (semplice -> complesso)

### Livello 0 - Navigazione documentazione (30-45 min)

Obiettivo: allenarti a trovare risposte in < 3 minuti.

Checklist:
- Trova dove si configura `app.baseUrl`.
- Trova differenza tra `app-config.yaml` e `app-config.production.yaml`.
- Trova come si definisce un `Component` nel catalogo.

Output pratico:
- Un file note con 3 URL ufficiali + una riga di sintesi per ciascuno.

### Livello 1 - Catalogo minimo (Component + System + Group)

Obiettivo: registrare entita semplici nel catalogo.

Leggi prima:
- https://backstage.io/docs/features/software-catalog/descriptor-format

Snippet base da copiare e personalizzare:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-api
  description: API per esercitazione CNPE
  tags: [backend, cnpe]
spec:
  type: service
  lifecycle: experimental
  owner: group:default/platform-team
  system: my-platform
---
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: my-platform
spec:
  owner: group:default/platform-team
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: platform-team
spec:
  type: team
  profile:
    displayName: Platform Team
  members: []
```

Personalizza solo:
- `metadata.name`
- `spec.owner`
- `spec.system`

### Livello 2 - Configurazione backend/frontend

Obiettivo: capire baseUrl, listen e cors senza confondersi.

Leggi prima:
- https://backstage.io/docs/conf/

Snippet minimo da verificare:

```yaml
app:
  baseUrl: http://192.168.1.60:3000

backend:
  baseUrl: http://192.168.1.60:7007
  listen:
    host: 0.0.0.0
    port: 7007
  cors:
    origin: http://192.168.1.60:3000
    methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
    credentials: true
```

Test veloce:
- Apri UI su 3000.
- Verifica login guest da UI.

### Livello 3 - Entita realistiche (API, Resource, Domain)

Obiettivo: modellare una piattaforma reale in modo progressivo.

Leggi prima:
- https://backstage.io/docs/features/software-catalog/

Esempi da aggiungere uno alla volta:
- `kind: API`
- `kind: Resource` (es. cluster, db)
- `kind: Domain`

Regola pratica: una nuova relazione per esercizio (es. `dependsOn`), non tutte insieme.

### Livello 4 - Template semplici (Scaffolder)

Obiettivo: creare un template basilare che genera skeleton progetto.

Leggi prima:
- https://backstage.io/docs/features/software-templates/getting-started
- https://backstage.io/docs/features/software-templates/writing-templates

Snippet super minimo:

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: simple-service
  title: Simple Service
spec:
  owner: group:default/platform-team
  type: service
  parameters:
    - title: Service Info
      required: [name]
      properties:
        name:
          type: string
  steps:
    - id: log
      name: Log input
      action: debug:log
      input:
        message: "Creating service ${{ parameters.name }}"
  output:
    text:
      - title: Result
        content: "Template eseguito"
```

Poi evolvi con una sola action nuova alla volta.

### Livello 5 - TechDocs base

Obiettivo: aggiungere documentazione tecnica navigabile da catalogo.

Leggi prima:
- https://backstage.io/docs/features/techdocs/

Passi:
1. Aggiungi `mkdocs.yml` minimo.
2. Aggiungi annotazione TechDocs all'entita.
3. Verifica pagina docs in UI.

### Livello 6 - Kubernetes plugin (integrazione semplice)

Obiettivo: visualizzare workload K8s da Backstage.

Leggi prima:
- https://backstage.io/docs/features/kubernetes/

Approccio:
1. Configura integrazione minima cluster.
2. Aggiungi annotazioni kubernetes su un componente.
3. Verifica tab Kubernetes in UI.

### Livello 7 - Auth e sicurezza API

Obiettivo: capire differenza tra endpoint pubblici e protetti.

Leggi prima:
- https://backstage.io/docs/auth/
- https://backstage.io/docs/auth/guest/provider

Esercizio:
1. Ottieni token guest.
2. Chiama endpoint catalog con bearer token.
3. Annota quali endpoint danno 401 senza credenziali.

### Livello 8 - Deployment e operativita (visione esame)

Obiettivo: collegare Backstage al mindset platform engineering CNCF.

Leggi prima:
- https://backstage.io/docs/deployment/
- https://backstage.io/docs/deployment/k8s

Poi mappa i concetti:
- Service/Ingress
- ConfigMap/Secret
- observability di base (logs/metrics/traces)

## Metodo anti-memoria (consigliato per esame)

Usa questa routine per ogni argomento:

1. Question: cosa devo ottenere?
2. Source: quale pagina ufficiale lo spiega?
3. Snippet: qual e il blocco minimo da copiare?
4. Adapt: quali 2 campi devo cambiare nel mio contesto?
5. Validate: quale comando/UI prova che funziona?
6. Note: cosa rifarei uguale la prossima volta?

## Template del tuo playbook personale

Copia questo schema e compilalo a ogni esercizio:

```md
# Argomento
- Obiettivo:
- URL ufficiale usata:
- Snippet copiato:
- Campi personalizzati:
- Come ho verificato:
- Errore incontrato:
- Fix:
- Lezione imparata:
```

## Mini roadmap 7 giorni (incrementale)

1. Giorno 1: Livelli 0-1
2. Giorno 2: Livello 2
3. Giorno 3: Livello 3
4. Giorno 4: Livello 4
5. Giorno 5: Livello 5
6. Giorno 6: Livello 6
7. Giorno 7: Livelli 7-8 + ripasso docs-first

Se mantieni questa disciplina, studi Backstage come strumento reale (navigando la documentazione ufficiale), non come lista di nozioni da memorizzare.

## Soluzioni passo passo (domanda -> esecuzione)

### Domanda 1: Dove configuro URL frontend e backend?

Soluzione passo passo:
1. Apri la doc ufficiale: https://backstage.io/docs/conf/
2. Cerca `app.baseUrl` e `backend.baseUrl`.
3. Apri `app-config.yaml` del tuo progetto.
4. Imposta:

```yaml
app:
  baseUrl: http://192.168.1.60:3000

backend:
  baseUrl: http://192.168.1.60:7007
  listen:
    host: 0.0.0.0
    port: 7007
```

5. Riavvia Backstage.
6. Verifica UI su `:3000`.

### Domanda 2: Come aggiungo il mio primo componente al catalogo?

Soluzione passo passo:
1. Apri: https://backstage.io/docs/features/software-catalog/descriptor-format
2. Copia un esempio `kind: Component`.
3. Crea/aggiorna un file YAML con il tuo componente.
4. Personalizza solo `metadata.name`, `spec.owner`, `spec.type`.
5. Registra il file nel catalogo da UI (`Create` -> `Register Existing Component`) oppure via `catalog.locations`.
6. Verifica che compaia nel Catalogo.

### Domanda 3: Perche `/api/catalog/entities` risponde 401?

Soluzione passo passo:
1. Apri doc auth guest: https://backstage.io/docs/auth/guest/provider
2. Conferma in `app-config.yaml`:

```yaml
auth:
  providers:
    guest: {}
```

3. Ottieni token guest:

```bash
TOKEN=$(curl -s http://192.168.1.60:7007/api/auth/guest/refresh | jq -r .backstageIdentity.token)
```

4. Usa il token sulla API protetta:

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://192.168.1.60:7007/api/catalog/entities
```

5. Se funziona, il 401 senza token era comportamento atteso.

### Domanda 4: Come creare un template Scaffolder minimo?

Soluzione passo passo:
1. Apri: https://backstage.io/docs/features/software-templates/writing-templates
2. Copia template minimo con un parametro `name`.
3. Salvalo in un file YAML dedicato.
4. Registra il template nel catalogo.
5. Apri `Create` in UI.
6. Esegui il template con input di test.
7. Verifica output step e log azioni.

### Domanda 5: Come aggiungere TechDocs base?

Soluzione passo passo:
1. Apri: https://backstage.io/docs/features/techdocs/
2. Aggiungi `mkdocs.yml` minimo nel repo del componente.
3. Aggiungi annotazione TechDocs all'entita nel catalogo.
4. Rigenera/riavvia.
5. Apri la pagina componente -> tab Docs.

### Domanda 6: Come integrare Kubernetes in modo semplice?

Soluzione passo passo:
1. Apri: https://backstage.io/docs/features/kubernetes/
2. Configura il plugin kubernetes come da doc ufficiale.
3. Aggiungi annotazioni kubernetes al componente.
4. Verifica in UI la tab Kubernetes.
5. Aggiungi una sola capability per volta (cluster, poi labels, poi dashboard).

### Domanda 7: Come trasformare ogni esercizio in materiale da esame (senza memoria)?

Soluzione passo passo:
1. Definisci 1 obiettivo operativo misurabile.
2. Individua 1 sola pagina ufficiale come fonte primaria.
3. Copia snippet minimo.
4. Personalizza al massimo 2 campi.
5. Esegui verifica tecnica (UI o API).
6. Registra nel playbook:
   - URL doc
   - snippet usato
   - errore/fix
   - criterio di successo
7. Ripeti lo stesso ciclo su scenario leggermente piu complesso.

### Domanda 8: Come preparare una simulazione CNPE progressiva con Backstage?

Soluzione passo passo:
1. Simulazione base:
   - 1 componente in catalogo
   - 1 team owner
2. Simulazione intermedia:
   - API + Resource + System con relazioni
   - test API con guest token
3. Simulazione avanzata:
   - template scaffolder funzionante
   - docs tecniche visibili in TechDocs
   - integrazione Kubernetes di base
4. Per ogni livello, valida sempre con evidenza (screenshot/UI o output API).
