**CNPE**

Certified Kubernetes Application Developer

**Platform Engineering Edition**

**Guida Completa per l\'Esame CNCF**

Argomenti coperti: Platform Engineering • Multi-Tenancy • Networking •
Storage • Autoscaling • FinOps

**🎓 Panoramica dell\'Esame CNPE**

Il CNPE (Certified Kubernetes Platform Engineer) della CNCF valuta la
capacità di progettare, implementare e gestire piattaforme Kubernetes
multi-tenant di livello enterprise. La certificazione copre l\'intero
ciclo di vita di una piattaforma interna per sviluppatori.

**Dominio dell\'Esame e Pesi**

  -----------------------------------------------------------------------
  **Dominio**              **Peso    **Argomenti Chiave**
                           %**       
  ------------------------ --------- ------------------------------------
  Platform Engineering     20%       IDP, Golden Paths, Developer
  Fundamentals                       Experience

  Kubernetes Multi-Tenancy 25%       Namespaces, vcluster, HNC,
                                     NetworkPolicy

  Networking & Storage     20%       CNI, Ingress, Gateway API, CSI,
                                     Backup

  Autoscaling & Compute    20%       HPA, VPA, KEDA, Cluster Autoscaler

  Cost Management & FinOps 15%       OpenCost, Right-sizing, Chargeback
  -----------------------------------------------------------------------

> **🎯 ESAME: L\'esame è pratico (hands-on). Dovrai configurare cluster
> Kubernetes reali. Tempo: 2 ore. Punteggio minimo: 66%.**

**📐 1. Platform Engineering Fundamentals**

**1.1 Platform-as-a-Product vs Traditional Infrastructure**

Il concetto fondamentale del Platform Engineering è trattare la
piattaforma interna come un prodotto, con il team platform nel ruolo di
provider e gli sviluppatori come clienti interni.

  -----------------------------------------------------------------------
  **Traditional Infrastructure**   **Platform-as-a-Product**
  -------------------------------- --------------------------------------
  Sviluppatori aprono ticket e     Self-service: provisioning autonomo
  aspettano                        

  Processi manuali, colli di       Automazione e Golden Paths predefiniti
  bottiglia                        

  Configurazioni inconsistenti     Ambiente standardizzato e ripetibile

  Ops come gatekeeper              Platform team come provider di
                                   prodotto

  Successo misurato su uptime      Successo misurato su adozione e
  infrastrutturale                 soddisfazione
  -----------------------------------------------------------------------

**1.2 I 5 Pilastri della Piattaforma**

-   Reduced Cognitive Load: gli sviluppatori si concentrano sulla
    business logic, non su YAML, networking o storage

-   Consistent Developer Experience: stessi workflow e strumenti,
    indipendentemente dal cluster o cloud sottostante

-   Self-Service Capabilities: portale o CLI per provisioning di
    namespace, database, secret senza ticket

-   Security by Default: policy OPA/Gatekeeper, network policies e RBAC
    applicati automaticamente

-   Observable Systems: logging, monitoring e tracing integrati
    out-of-the-box per ogni workload

**1.3 Internal Developer Platform (IDP) - Componenti**

  -----------------------------------------------------------------------
  **Componente**     **Strumenti Comuni**  **Scopo**
  ------------------ --------------------- ------------------------------
  Portal / UI        Backstage, Port       Interfaccia self-service per
                                           sviluppatori

  GitOps Engine      ArgoCD, Flux          Sincronizzazione stato
                                           desiderato

  Policy Engine      OPA/Gatekeeper,       Enforcement regole di
                     Kyverno               sicurezza

  Secret Management  Vault, External       Gestione credenziali e segreti
                     Secrets               

  Service Catalog    Backstage, Crossplane Catalogo servizi e template

  Observability      Prometheus, Grafana,  Monitoraggio, logging,
                     Loki                  alerting

  Cost Management    OpenCost, Kubecost    Visibility e ottimizzazione
                                           costi

  Infrastructure     Terraform,            IaC e automazione
  Provisioning       Crossplane, Morpheus  infrastruttura
  -----------------------------------------------------------------------

> 💡 Golden Path: percorso preconfigurato e opinionato che guida gli
> sviluppatori verso le best practice senza richiedere expertise
> infrastrutturale.
>
> **🎯 ESAME: L\'esame testa la comprensione del modello
> Platform-as-a-Product e la capacità di identificare i componenti
> corretti per uno scenario IDP dato.**

**🏗️ 2. Kubernetes Multi-Tenancy**

**2.1 Modelli di Multi-Tenancy a Confronto**

  -----------------------------------------------------------------------------------
  **Modello**        **Isolamento**   **Costo**   **Compliance**   **Use Case**
  ------------------ ---------------- ----------- ---------------- ------------------
  Namespace-Based    Logico (RBAC +   Basso       Complessa        Team interni,
                     NetPol)                                       dev/test

  Cluster-Based      Fisico completo  Alto        Nativa           Regulated
                                                                   workloads, clienti
                                                                   esterni

  Virtual Cluster    API-level        Medio       Moderata         Dev/Test sandbox,
  (vcluster)                                                       multi-client

  Hierarchical       Ereditato        Basso       Moderata         Team con struttura
  Namespace (HNC)                                                  gerarchica
  -----------------------------------------------------------------------------------

**2.2 Namespace-Based Multi-Tenancy**

**Cosa isolano i namespace**

-   Nomi delle risorse (due team possono avere entrambi un deployment
    \'frontend\')

-   RBAC e ServiceAccount: permessi granulari per namespace

-   ResourceQuota: limiti di consumo applicati per namespace

-   NetworkPolicy scope: regole di rete applicabili a livello di
    namespace

**Cosa NON isolano i namespace**

-   Risorse dei nodi: CPU, memoria e disco sono condivisi a livello di
    cluster

-   Risorse cluster-scoped: Nodes, PersistentVolumes, ClusterRoles sono
    globali

-   Traffico di rete: senza NetworkPolicy, il traffico e\' permesso di
    default

-   Container runtime: kernel condiviso tra tutti i pod

> ⚠️ Senza NetworkPolicy e RBAC ben configurati, i namespace offrono
> solo isolamento logico dei nomi, non sicurezza reale.

**2.3 ResourceQuota - Tipologie e Configurazione**

**Le ResourceQuota limitano il consumo aggregato di risorse a livello di
namespace.**

**Compute Resource Quotas**

> apiVersion: v1
>
> kind: ResourceQuota
>
> metadata:
>
> name: team-prod-quota
>
> namespace: team-prod
>
> spec:
>
> hard:
>
> requests.cpu: \'10\' \# Totale CPU richieste
>
> requests.memory: 20Gi \# Totale memoria richiesta
>
> limits.cpu: \'20\' \# Totale CPU limiti
>
> limits.memory: 40Gi \# Totale memoria limiti
>
> pods: \'50\' \# Numero massimo di pod
>
> services.loadbalancers: \'2\' \# Limita servizi costosi!
>
> persistentvolumeclaims: \'10\'

**Storage Quotas per StorageClass**

> spec:
>
> hard:
>
> requests.storage: 100Gi
>
> fast-ssd.storageclass.storage.k8s.io/requests.storage: 50Gi
>
> standard.storageclass.storage.k8s.io/requests.storage: 50Gi

**2.4 LimitRange - Default e Vincoli**

> apiVersion: v1
>
> kind: LimitRange
>
> metadata:
>
> name: team-prod-defaults
>
> namespace: team-prod
>
> spec:
>
> limits:
>
> \- type: Container
>
> default:
>
> cpu: \'500m\'
>
> memory: \'512Mi\'
>
> defaultRequest:
>
> cpu: \'100m\'
>
> memory: \'128Mi\'
>
> min:
>
> cpu: \'50m\'
>
> memory: \'64Mi\'
>
> max:
>
> cpu: \'4\'
>
> memory: \'8Gi\'
>
> \- type: PersistentVolumeClaim
>
> min: { storage: 1Gi }
>
> max: { storage: 100Gi }

  -----------------------------------------------------------------------
  **Tipo**        **Scope**             **Funzione**
  --------------- --------------------- ---------------------------------
  ResourceQuota   Namespace intero      Limita somma risorse di tutti i
                                        pod nel namespace

  LimitRange      Singolo               Imposta default e limiti min/max
                  Container/Pod/PVC     per risorsa
  -----------------------------------------------------------------------

> **🎯 ESAME: Differenza critica: ResourceQuota limita il totale del
> namespace, LimitRange limita i singoli oggetti. Entrambi possono
> coesistere.**

**2.5 Namespace Naming Best Practices**

  ------------------------------------------------------------------------
  **Approccio**       **Esempi**                **Use Case**
  ------------------- ------------------------- --------------------------
  Environment-Based   team-a-dev,               Team con cicli di rilascio
                      team-a-staging,           strutturati
                      team-a-prod               

  Project-Based       payment-service,          Architetture a
                      inventory-service         microservizi

  Hybrid              payment-dev,              Enterprise platform,
  (raccomandato)      payment-staging,          bilanciamento
                      payment-prod              chiarezza/flessibilita\'
  ------------------------------------------------------------------------

**2.6 Hierarchical Namespace Controller (HNC)**

HNC consente di creare gerarchie di namespace con ereditarieta\'
automatica di risorse.

-   RBAC roles: definizioni centralizzate nel parent, disponibili in
    tutti i child

-   ConfigMaps e NetworkPolicies: propagate automaticamente verso il
    basso

-   ResourceQuota: gestita a livello parent

-   Riduzione duplicazione: singola fonte di verita\' per policy
    condivise

> \# Creazione SubnamespaceAnchor per creare namespace figlio
>
> apiVersion: hnc.x-k8s.io/v1alpha2
>
> kind: SubnamespaceAnchor
>
> metadata:
>
> name: frontend-dev
>
> namespace: team-frontend \# namespace parent

**2.7 Virtual Cluster (vcluster)**

vcluster crea cluster Kubernetes virtuali che girano come pod nel host
cluster, offrendo isolamento completo del control plane.

  -----------------------------------------------------------------------
  **Componente**          **Descrizione**
  ----------------------- -----------------------------------------------
  API Server virtuale     k3s o k0s dedicato per tenant - il tenant ha
                          accesso root

  virtual etcd/SQLite     Storage isolato per lo stato del cluster
                          virtuale

  Syncer                  Traduce risorse virtuali in risorse reali nel
                          host cluster

  virtual nodes/pods      Il tenant vede nodi e pod propri, non quelli
                          del host

  CRDs tenant             Il tenant puo\' installare CRD senza impattare
                          altri tenant
  -----------------------------------------------------------------------

> 💡 vcluster e\' ideale per: ambienti dev/test, multi-tenancy
> regolamentata con clienti esterni, testing di upgrade Kubernetes senza
> rischi.

**🌐 3. Network Policy & Isolamento**

**3.1 Pattern Default-Deny**

Il pattern fondamentale e\': bloccare tutto il traffico di default, poi
autorizzare esplicitamente solo il necessario.

> \# Step 1: Default deny TUTTO il traffico
>
> apiVersion: networking.k8s.io/v1
>
> kind: NetworkPolicy
>
> metadata:
>
> name: default-deny-all
>
> namespace: team-prod
>
> spec:
>
> podSelector: {} \# Seleziona TUTTI i pod
>
> policyTypes:
>
> \- Ingress
>
> \- Egress
>
> \# Step 2: CRITICO - Permettere DNS (senza, nessun pod puo\' risolvere
> nomi)
>
> spec:
>
> podSelector: {}
>
> policyTypes: \[Egress\]
>
> egress:
>
> \- to:
>
> \- namespaceSelector:
>
> matchLabels:
>
> kubernetes.io/metadata.name: kube-system
>
> podSelector:
>
> matchLabels:
>
> k8s-app: kube-dns
>
> ports:
>
> \- port: 53
>
> protocol: UDP
>
> ⚠️ CRITICO: Senza la policy DNS, tutti i pod nel namespace non possono
> risolvere i nomi dei servizi. Le applicazioni falliscono
> silenziosamente.

**3.2 Workflow in 5 Passi per Network Policy**

  -----------------------------------------------------------------------------
  **Step**   **Azione**                  **Motivazione**
  ---------- --------------------------- --------------------------------------
  1          Applicare default-deny      Principio del minimo privilegio: tutto
             ingress + egress            bloccato di default

  2          Permettere egress DNS porta Senza DNS, i pod non risolvono i
             53 UDP verso kube-dns       servizi

  3          Permettere traffico         Abilitare traffico HTTP/HTTPS esterno
             dall\'Ingress Controller    

  4          Permettere comunicazione    Pod dello stesso team possono
             same-namespace              comunicare

  5          Permettere servizi          Solo i path di comunicazione
             specifici cross-namespace   strettamente necessari
  -----------------------------------------------------------------------------

**3.3 CNI Plugin a Confronto**

  -------------------------------------------------------------------------
  **CNI**        **Sicurezza**         **Performance**    **Use Case**
  -------------- --------------------- ------------------ -----------------
  Calico         NetworkPolicy L3/L4,  Scalabilita\' fino On-premise,
                 isolamento BGP        a \~10k nodi       hybrid cloud,
                                                          compliance
                                                          rigorosa

  Cilium         Policy eBPF L3-L7,    Accelerazione      Multi-cluster
                 crittografia nativa   datapath eBPF,     mesh,
                                       latenza sub-ms     osservabilita\'
                                                          zero-trust

  AWS VPC CNI    Security Groups, VPC  Nessun overlay     Deployments
                 Flow Logs             overhead, limiti   EKS-native,
                                       ENI                integrazione AWS
                                                          nativa

  Flannel        Solo base (no         Semplice e leggero Ambienti di
                 NetworkPolicy nativo)                    sviluppo, cluster
                                                          piccoli
  -------------------------------------------------------------------------

**3.4 Ingress Pattern & Gateway API**

  -----------------------------------------------------------------------
  **Pattern**        **Caratteristiche**         **Quando Usare**
  ------------------ --------------------------- ------------------------
  Single Ingress     NGINX centralizzato,        Cluster piccoli,
  Controller         routing host/path           semplicita\' operativa

  Multi-Tenant       Controller cluster-wide con Cluster multi-team con
  Ingress            tenant isolation via RBAC   isolamento
                                                 configurazioni

  Gateway API        Standard Kubernetes         Nuovi deployment,
                     emergente (v1.0),           massima flessibilita\' e
                     separazione ruoli           futuro standard
                     platform/app team           
  -----------------------------------------------------------------------

**3.5 Service Mesh - Quando Usare e Quando Evitare**

  -----------------------------------------------------------------------
  **Usare Service Mesh**              **Evitare Service Mesh**
  ----------------------------------- -----------------------------------
  mTLS: zero-trust networking tra     App monolitiche o pochi
  servizi                             microservizi

  Canary deployment con traffic       Latenza critica: il sidecar
  splitting preciso                   aggiunge \~5ms overhead

  Distributed tracing end-to-end      Team senza expertise per gestire la
                                      complessita\'

  Advanced traffic management (A/B,   Workload semplici senza requisiti
  blue/green)                         avanzati
  -----------------------------------------------------------------------

> **🎯 ESAME: L\'esame testa la capacita\' di scrivere NetworkPolicy
> corrette. Ricorda sempre: 1) default-deny prima, 2) DNS e\'
> obbligatorio, 3) ogni allow deve essere esplicito.**

**💾 4. Storage in Kubernetes**

**4.1 Architettura Storage**

**Storage Classes & CSI Drivers piu\' comuni**

  ------------------------------------------------------------------------------
  **CSI Driver**   **Tipo**           **Provider**   **Use Case**
  ---------------- ------------------ -------------- ---------------------------
  AWS EBS CSI      Block storage      AWS            Volumi persistenti
                                                     single-node

  AWS EFS CSI      File storage       AWS            Storage ReadWriteMany tra
                   condiviso                         pod

  Longhorn         Distributed block  On-prem        HA storage self-hosted

  Rook-Ceph        Software-defined   On-prem        Storage enterprise
                   storage                           self-managed

  Azure Disk CSI   Block storage      Azure          Volumi persistenti AKS

  GCE PD CSI       Block/File storage GCP            Volumi persistenti GKE
  ------------------------------------------------------------------------------

**4.2 Static vs Dynamic Provisioning**

  -----------------------------------------------------------------------
                     **Static Provisioning**   **Dynamic Provisioning
                                               (raccomandato)**
  ------------------ ------------------------- --------------------------
  Chi crea il PV     Amministratore            Kubernetes automaticamente
                     manualmente               via StorageClass

  Flusso             Admin crea PV → Developer Developer crea PVC →
                     crea PVC → Binding        StorageClass crea PV
                                               automaticamente

  Flessibilita\'     Bassa (pre-sizing         Alta (on-demand,
                     necessario)               dimensioni esatte)

  Use Case           Storage legacy, hardware  Cloud provider, ambienti
                     dedicato                  modern
  -----------------------------------------------------------------------

**4.3 Data Protection**

-   Velero Backup: backup e restore a livello cluster (namespace, PVC,
    CRD incluse)

-   Volume Snapshots: snapshot nativi per CSI drivers (VolumeSnapshot,
    VolumeSnapshotClass)

-   Cross-Region Replication: replicazione asincrona tra availability
    zones

> \# Esempio VolumeSnapshotClass
>
> apiVersion: snapshot.storage.k8s.io/v1
>
> kind: VolumeSnapshotClass
>
> metadata:
>
> name: csi-aws-vsc
>
> driver: ebs.csi.aws.com
>
> deletionPolicy: Delete
>
> **🎯 ESAME: L\'esame puo\' chiedere di configurare StorageClass con
> binding mode, reclaim policy e allowVolumeExpansion. Conosci le
> differenze tra Retain, Delete e Recycle.**

**⚡ 5. Autoscaling in Kubernetes**

**5.1 Panoramica degli Autoscaler**

  ----------------------------------------------------------------------------
  **Autoscaler**   **Livello**   **Scala**                **Trigger**
  ---------------- ------------- ------------------------ --------------------
  HPA              Pod           Numero di repliche       CPU, memoria, custom
                                 (orizzontale)            metrics

  VPA              Pod           Dimensione container     Utilizzo storico
                                 (verticale)              CPU/memoria

  KEDA             Pod           Numero di repliche +     Eventi: Kafka, HTTP,
                                 scale-to-zero            cron, SQS\...

  Cluster          Nodo          Numero di nodi nel       Pod pending, nodi
  Autoscaler                     cluster                  sottoutilizzati
  ----------------------------------------------------------------------------

**5.2 HPA - Horizontal Pod Autoscaler**

> apiVersion: autoscaling/v2
>
> kind: HorizontalPodAutoscaler
>
> metadata:
>
> name: frontend-hpa
>
> spec:
>
> scaleTargetRef:
>
> apiVersion: apps/v1
>
> kind: Deployment
>
> name: frontend
>
> minReplicas: 3
>
> maxReplicas: 20
>
> metrics:
>
> \- type: Resource
>
> resource:
>
> name: cpu
>
> target:
>
> type: Utilization
>
> averageUtilization: 70
>
> behavior:
>
> scaleUp:
>
> stabilizationWindowSeconds: 0 \# Immediato
>
> policies:
>
> \- type: Percent
>
> value: 100 \# +100% (raddoppio)
>
> periodSeconds: 15
>
> \- type: Pods
>
> value: 4 \# O +4 pod
>
> periodSeconds: 15
>
> selectPolicy: Max \# Usa la piu\' aggressiva
>
> scaleDown:
>
> stabilizationWindowSeconds: 300 \# 5 minuti
>
> policies:
>
> \- type: Percent
>
> value: 10 \# -10% per minuto
>
> periodSeconds: 60
>
> 💡 Scale-up aggressivo (risposta rapida ai picchi), scale-down
> conservativo (prevenzione thrashing). Questa asimmetria e\' una best
> practice fondamentale.

**5.3 VPA - Vertical Pod Autoscaler**

VPA analizza l\'utilizzo storico e raccomanda o applica automaticamente
i resource requests/limits corretti.

  ------------------------------------------------------------------------
  **Update       **Comportamento**             **Quando Usare**
  Mode**                                       
  -------------- ----------------------------- ---------------------------
  Off            Solo raccomandazioni, nessuna Prima implementazione,
                 modifica                      analisi e planning

  Initial        Applica a nuovi pod, non      Rollout graduale, ambienti
                 modifica esistenti            production-sensitive

  Auto           Evicta pod esistenti e ricrea Massima automazione,
                 con nuovi valori              workload non-critical
  ------------------------------------------------------------------------

> apiVersion: autoscaling.k8s.io/v1
>
> kind: VerticalPodAutoscaler
>
> metadata:
>
> name: backend-vpa
>
> spec:
>
> targetRef:
>
> apiVersion: apps/v1
>
> kind: Deployment
>
> name: backend
>
> updatePolicy:
>
> updateMode: \'Auto\'
>
> resourcePolicy:
>
> containerPolicies:
>
> \- containerName: \'\*\'
>
> minAllowed:
>
> cpu: 100m
>
> memory: 128Mi
>
> maxAllowed:
>
> cpu: 4
>
> memory: 8Gi
>
> ⚠️ Non usare HPA e VPA sulla stessa metrica (es. entrambi su CPU%).
> Crea un loop infinito di scaling. HPA su custom metrics + VPA su
> CPU/memory e\' la combinazione corretta.

**5.4 KEDA - Event-Driven Autoscaling**

KEDA estende Kubernetes per permettere scaling basato su eventi e
abilita il pattern scale-to-zero.

> apiVersion: keda.sh/v1alpha1
>
> kind: ScaledObject
>
> metadata:
>
> name: kafka-consumer-scaler
>
> spec:
>
> scaleTargetRef:
>
> name: kafka-consumer
>
> minReplicaCount: 0 \# Scale to zero!
>
> maxReplicaCount: 100
>
> pollingInterval: 30 \# Controlla ogni 30s
>
> cooldownPeriod: 300 \# 5min prima di scale-down a zero
>
> triggers:
>
> \- type: kafka
>
> metadata:
>
> bootstrapServers: kafka.default.svc:9092
>
> consumerGroup: my-consumer-group
>
> topic: events
>
> lagThreshold: \'100\' \# Scala se consumer lag \> 100 msg

  ------------------------------------------------------------------------
  **Trigger KEDA**   **Descrizione**         **Metrica di Scaling**
  ------------------ ----------------------- -----------------------------
  kafka              Apache Kafka consumer   Messaggi in arretrato per
                     lag                     partition

  rabbitmq           RabbitMQ queue length   Numero di messaggi in coda

  aws-sqs-queue      AWS SQS message count   ApproximateNumberOfMessages

  prometheus         Query PromQL custom     Qualsiasi metrica Prometheus

  http               HTTP request rate       Richieste per secondo

  cron               Schedule temporizzato   Scaling su orari predefiniti
  ------------------------------------------------------------------------

**5.5 Cluster Autoscaler**

Il Cluster Autoscaler gestisce il numero di nodi nel cluster aggiungendo
nodi quando ci sono pod Pending e rimuovendo nodi sottoutilizzati.

  -----------------------------------------------------------------------
  **Expander         **Selezione**               **Best For**
  Strategy**                                     
  ------------------ --------------------------- ------------------------
  random             Casuale tra node group      Testing, nessuna
                     eleggibili                  preferenza

  most-pods          Node group che schedula     Massimizzare throughput
                     piu\' pod pending           schedulazione

  least-waste        Node group con meno risorse Ottimizzazione costi
                     idle post-scheduling        (raccomandato)

  price              Node group a minor costo    Riduzione costi
                                                 prioritaria

  priority           Basato su ConfigMap con     Controllo totale sulla
                     priorita\' custom           selezione
  -----------------------------------------------------------------------

> \# Parametri Cluster Autoscaler chiave
>
> \--expander=least-waste \# Strategia selezione node group
>
> \--scale-down-delay-after-add=10m \# Aspetta 10min dopo scale-up prima
> di scale-down
>
> \--scale-down-unneeded-time=10m \# Nodo inutilizzato per 10min prima
> di rimozione
>
> \--balance-similar-node-groups \# Bilancia tra Availability Zones
>
> **🎯 ESAME: Combination pattern fondamentale: HPA/KEDA scala i pod
> (application layer) -\> Cluster Autoscaler scala i nodi
> (infrastructure layer). I due layer sono indipendenti e
> complementari.**

**💰 6. Cost Management & FinOps**

**6.1 Perche\' il Cost Tracking in Kubernetes e\' Complesso**

  -----------------------------------------------------------------------
  **Infrastruttura Tradizionale**  **Kubernetes**
  -------------------------------- --------------------------------------
  Server dedicati per team         Nodi condivisi tra multipli workload
  (mappatura 1:1)                  

  Billing semplice basato su       Dynamic scaling cambia consumo
  capacita\' provisionata          continuamente

  Proprieta\' chiara di ogni       System overhead (kube-system)
  risorsa                          difficile da attribuire

  Costo facilmente mappabile a     Necessita\' di allocazione costi
  team/progetto                    complessa
  -----------------------------------------------------------------------

**6.2 Componenti di Costo Kubernetes**

-   Compute Costs: CPU, memoria, GPU (costo istanze node)

-   Storage Costs: Persistent Volumes, StorageClass diverse, snapshot

-   Network Costs: trasferimento dati cross-AZ, egress verso internet,
    Load Balancer

-   Cluster Overhead: control plane managed (EKS/GKE/AKS fees),
    componenti sistema

**6.3 OpenCost - Architettura**

OpenCost e\' un progetto CNCF per il tracking dei costi Kubernetes in
real-time.

  -----------------------------------------------------------------------
  **Componente**        **Funzione**
  --------------------- -------------------------------------------------
  OpenCost Pod          Deployment nel cluster, versione 2.0 con Promless
                        mode e AI integration

  Kubernetes API        Query per metriche risorse: pod, node, PVC,
                        namespace

  Cloud Provider APIs   Sync prezzi reali da AWS Cost Explorer, GCP
                        Billing, Azure Billing

  Pricing Data Store    Storage persistente per modelli di costo
                        combinati

  Prometheus Endpoint   Espone metriche per integrazione con stack
                        monitoring esistente

  Grafana Dashboards    Visualizzazione real-time con dashboard
                        pre-configurate
  -----------------------------------------------------------------------

**6.4 Metodi di Allocazione Costi**

  --------------------------------------------------------------------------------------------------
  **Metodo**        **Granularita\'**   **Flessibilita\'**   **Complessita\'**   **Best For**
  ----------------- ------------------- -------------------- ------------------- -------------------
  Namespace-Based   Alta (per           Media                Bassa               Team boundaries,
                    namespace)                                                   chargeback semplice

  Label-Based       Molto alta          Massima              Media               Multi-dimensional
                    (cross-namespace)                                            reporting

  Proportional      Dipende dalla       Alta                 Alta                Shared costs,
  Allocation        strategia                                                    overhead allocation
  --------------------------------------------------------------------------------------------------

**6.5 Showback vs Chargeback**

  -----------------------------------------------------------------------
                        **Showback**             **Chargeback**
  --------------------- ------------------------ ------------------------
  Meccanismo            Report periodici, nessun Addebito reale ai budget
                        trasferimento denaro     dei team

  Accountability        Indiretta (awareness)    Diretta (impatto budget)

  Frizione              Bassa                    Alta
  organizzativa                                  

  Complessita\'         Bassa                    Alta

  Quando usare          Inizio journey FinOps,   FinOps maturo, forte
                        cultura non pronta       accountability
                                                 necessaria
  -----------------------------------------------------------------------

> 💡 Best Practice: inizia con Showback per creare awareness, poi evolvi
> verso Chargeback quando la cultura organizzativa e\' pronta.

**6.6 Right-Sizing e Strategie di Ottimizzazione**

  ------------------------------------------------------------------------
  **Strategia**       **Risparmio       **Implementazione**
                      Atteso**          
  ------------------- ----------------- ----------------------------------
  Right-sizing        30-40% costi      VPA in Off mode per analisi, poi
  workload            compute           Initial/Auto

  Spot Instances      70-90% su         Node group spot per CI/CD, batch,
                      workload idonei   dev

  Reserved Instances  40-60% sul        1-3 anni commitment per workload
                      baseline          stabili

  Idle resource       10-15% immediato  OpenCost per identificare, poi
  cleanup                               eliminare

  Scale-to-zero con   100% durante idle Dev/test ambienti, workload
  KEDA                                  sporadici
  ------------------------------------------------------------------------

**6.7 FinOps Framework - 3 Pilastri**

-   Visibility: dashboard real-time, cost allocation charts, trend
    forecasting

-   Optimization: right-sizing continuo, waste elimination, architettura
    cost-aware

-   Governance: budget alerts, anomaly detection, approval workflow per
    risorse ad alto costo

**6.8 Pre-Deployment Cost Gates**

Integrare la stima dei costi nella CI/CD pipeline per prevenire
deployment costosi non autorizzati:

-   Cost estimation engine calcola costo proiettato prima del deploy

-   Budget check: blocco automatico se supera quota team

-   GitOps PR comments con cost impact comparison (Delta: +2.3% vs
    baseline)

-   Admission Controller: ultimo check prima del deployment

-   Deployment taggato con costo mensile stimato per tracciabilita\'

> **🎯 ESAME: L\'esame testa la comprensione di come configurare
> namespace-based cost allocation e la differenza tra showback e
> chargeback.**

**🎯 7. Domande di Preparazione all\'Esame**

**7.1 Platform Engineering**

**D1: Qual e\' la differenza principale tra una IDP e un\'infrastruttura
tradizionale?**

R: L\'IDP tratta gli sviluppatori come clienti, offrendo self-service e
golden paths. L\'infrastruttura tradizionale richiede ticket e ha l\'Ops
come gatekeeper.

**D2: Cosa si intende per \'Golden Path\' in Platform Engineering?**

R: Un percorso preconfigurato e opinionato che guida gli sviluppatori
verso le best practice senza richiedere expertise infrastrutturale.
Riduce il cognitive load.

**7.2 Multi-Tenancy**

**D3: Qual e\' la differenza tra ResourceQuota e LimitRange?**

R: ResourceQuota limita il totale aggregato del namespace (es. max 50
pod in totale). LimitRange imposta default e limiti per singolo
container/pod/PVC.

**D4: In quale scenario sceglieresti vcluster invece di namespace-based
tenancy?**

R: Quando i tenant hanno requisiti di isolamento forte (es. clienti
esterni, compliance), quando devono installare CRD proprie, o quando
serve piena autonomia del control plane senza il costo di cluster
dedicati.

**D5: Cosa eredita un child namespace da un parent in HNC?**

R: RBAC roles, ConfigMaps propagate, NetworkPolicies e ResourceQuota
(configurabili). L\'ereditarieta\' riduce la duplicazione delle policy.

**7.3 NetworkPolicy**

**D6: Perche\' e\' necessario permettere DNS anche dopo aver applicato
default-deny?**

R: Senza DNS (porta 53 UDP verso kube-dns in kube-system), i pod non
possono risolvere i nomi dei servizi Kubernetes. Le applicazioni
falliscono silenziosamente.

**D7: Cosa significa che i namespace non isolano il traffico di rete per
default?**

R: Senza NetworkPolicy, tutto il traffico tra pod di namespace diversi
e\' permesso. L\'isolamento reale richiede l\'applicazione esplicita di
NetworkPolicy con default-deny.

**7.4 Autoscaling**

**D8: Perche\' non si devono usare HPA e VPA sulla stessa metrica (es.
CPU)?**

R: Crea un loop infinito: HPA aumenta pod perche\' CPU e\' alta -\> VPA
riduce il request CPU -\> CPU% torna alta -\> HPA aumenta ancora. La
combinazione corretta e\' HPA su custom metrics e VPA su CPU/memory.

**D9: Qual e\' la differenza tra scale-up aggressivo e scale-down
conservativo in HPA?**

R: Scale-up aggressivo (window=0, +100% ogni 15s) risponde rapidamente
ai picchi per evitare degradazione. Scale-down conservativo
(window=300s, -10%/min) previene il thrashing (oscillazione continua).

**D10: Cosa permette KEDA che HPA nativo non puo\' fare?**

R: Scale-to-zero: KEDA puo\' scalare a 0 repliche quando non ci sono
eventi. HPA ha minReplicas \>= 1. KEDA supporta anche eventi da sistemi
esterni (Kafka, SQS, ecc.).

**7.5 FinOps**

**D11: Qual e\' il target di efficienza ottimale per il right-sizing dei
workload?**

R: 60-80% di utilizzo delle risorse richieste. Sotto il 30% indica
over-provisioning; sopra il 90% indica rischio di throttling o OOMKill.

**D12: Quando si usa Chargeback vs Showback?**

R: Showback all\'inizio del journey FinOps per creare awareness senza
frizione. Chargeback in organizzazioni mature dove si vuole
accountability diretta con impatto reale sul budget.

**7.6 Scenari Pratici**

**Scenario A: Un team di data engineering vuole ambienti di sviluppo
Kubernetes isolati che possono essere accesi solo durante le ore
lavorative.**

Soluzione: KEDA con trigger cron per scale-to-zero la notte e nei
weekend. Namespace dedicati con ResourceQuota. Per isolamento forte:
vcluster con startup/shutdown schedulati.

**Scenario B: Il team platform deve garantire che nessun pod possa
essere creato senza resource requests definiti.**

Soluzione: LimitRange con defaultRequest impostato. Kyverno/OPA policy
che rifiuta pod senza requests. Alternativa: Pod Security Admission.

**Scenario C: Come allocare il costo del control plane managed (EKS fee:
\$73/cluster/mese) tra 5 team?**

Soluzione: Proportional allocation in OpenCost basata sull\'utilizzo
risorse (peso proporzionale al consumo CPU+memory) o equal split
(\$14.6/team/mese). Documentare la strategia scelta.

**📋 8. Cheat Sheet - Comandi e Risorse**

**8.1 kubectl per Multi-Tenancy**

> \# Visualizzare ResourceQuota di un namespace
>
> kubectl describe resourcequota -n team-prod
>
> \# Visualizzare LimitRange
>
> kubectl describe limitrange -n team-prod
>
> \# Verificare stato HPA
>
> kubectl get hpa -n production
>
> kubectl describe hpa frontend-hpa -n production
>
> \# Verificare pod pending (trigger Cluster Autoscaler)
>
> kubectl get pods \--all-namespaces \| grep Pending
>
> \# Verificare utilizzo risorse nodi
>
> kubectl top nodes
>
> kubectl top pods -n team-prod
>
> \# Verificare NetworkPolicy
>
> kubectl get networkpolicy -n team-prod
>
> kubectl describe networkpolicy default-deny-all -n team-prod

**8.2 Decisional Framework Rapido**

  -----------------------------------------------------------------------
  **Requisito**               **Soluzione**
  --------------------------- -------------------------------------------
  Isolamento leggero tra team Namespace + ResourceQuota + LimitRange +
  interni                     NetworkPolicy

  Isolamento forte con API    vcluster
  K8s completa per tenant     

  Gerarchia team con          Hierarchical Namespace Controller (HNC)
  ereditarieta\' policy       

  Scaling basato su           HPA con autoscaling/v2
  CPU/memoria                 

  Scaling basato su eventi    KEDA
  (Kafka, SQS, cron)          

  Right-sizing automatico     VPA in modalita\' Auto o Initial
  risorse container           

  Aggiunta automatica nodi al Cluster Autoscaler con least-waste expander
  cluster                     

  Visibilita\' costi per      OpenCost con namespace-based allocation
  namespace/team              

  Blocco traffico di rete per NetworkPolicy default-deny + explicit-allow
  default                     

  Policy compliance e         OPA/Gatekeeper o Kyverno
  governance                  

  Storage block persistente   StorageClass + CSI driver + dynamic
  on-demand                   provisioning

  Backup cluster completo     Velero + VolumeSnapshot

  Ingress moderno con         Gateway API con HTTPRoute
  separazione ruoli           
  -----------------------------------------------------------------------

**8.3 Request/Limit Ratio Raccomandati**

  ------------------------------------------------------------------------
  **Risorsa**    **Request:Limit       **Motivazione**
                 Ratio**               
  -------------- --------------------- -----------------------------------
  CPU            1:2 (es. 500m:1000m)  CPU e\' compressibile: throttling
                                       senza kill, ratio piu\' ampio
                                       accettabile

  Memory         1:1 (es. 512Mi:512Mi) Memory NON e\' compressibile:
                                       OOMKill se supera il limit

  GPU            1:1 (es. 1:1)         Le GPU non sono condivisibili,
                                       sempre 1:1
  ------------------------------------------------------------------------

**8.4 Anti-Pattern da Evitare all\'Esame**

-   HPA + VPA sulla stessa metrica CPU -\> loop infinito

-   NetworkPolicy senza permettere DNS -\> pod non risolvono servizi

-   ResourceQuota senza LimitRange -\> pod senza requests consumano
    quota illimitata

-   vcluster per team interni semplici -\> overhead inutile (usare
    namespace)

-   Cluster Autoscaler senza resource requests sui pod -\> non funziona
    correttamente

-   Scale-down aggressivo HPA -\> thrashing continuo

-   Memory limit \>\> request in modo significativo -\> OOMKill risk

> 💡 Strategia esame: leggi attentamente il requisito del scenario. Le
> parole chiave sono fondamentali: \'isolamento forte\' -\> vcluster,
> \'gerarchia\' -\> HNC, \'event-driven\' -\> KEDA, \'cost tracking\'
> -\> OpenCost.
>
> **🎯 ESAME: L\'esame CNPE e\' hands-on. Pratica la configurazione di
> NetworkPolicy, ResourceQuota, HPA e KEDA su un cluster reale
> (minikube, kind, o k3s). La velocita\' di esecuzione e\' critica.**

Guida CNPE - Cloud Native Computing Foundation \| Kubernetes Platform
Engineering

Basata sul curriculum ufficiale CNCF CNPE
