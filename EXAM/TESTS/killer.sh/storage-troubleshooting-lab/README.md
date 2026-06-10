# CNPE Storage Troubleshooting Lab

Laboratorio pratico composto da 20 incidenti storage indipendenti in stile
esame CNPE. Ogni domanda parte da risorse già guaste nel cluster e richiede
triage, diagnosi, correzione e verifica.

Gli scenari coprono:

- PVC `Pending` e binding statico;
- selector, capacità, access mode, StorageClass e pre-binding;
- ConfigMap, Secret, projected volume, `subPath` e mount read-only;
- StatefulSet e volumeClaimTemplate;
- local PV, node affinity e scheduling;
- reclaim policy `Retain` e recupero di PV `Released`;
- volume mode e permessi per container non-root.

Ogni domanda usa il Namespace `storage-qNN` e la directory
`~/course-storage-troubleshooting/NN/`. Le domande non dipendono tra loro.

## Avvio con kind

Prerequisiti: Docker o Podman, `kind` e `kubectl`.

```bash
./setup-storage-troubleshooting-lab-kind.sh
```

Il wrapper crea un cluster a tre nodi per gli esercizi sui local PV.

## Avvio su cluster esistente

Il cluster deve avere almeno due nodi schedulabili.

```bash
CLUSTER_PROVIDER=existing ./setup-storage-troubleshooting-lab.sh
```

Per rigenerare tutti gli incidenti:

```bash
LAB_FORCE=true ./setup-storage-troubleshooting-lab-kind.sh
```
