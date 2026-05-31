# CNPE Batteria 06 - Stateful Platform, Backup e Disaster Recovery

Focus strumenti: StatefulSet, CSI snapshots, Velero, etcd backup, PV policy, RPO/RTO.

## Domande (10)
1. Deploy database stateful con PVC e storageclass dedicata.
2. Imposta PodDisruptionBudget e anti-affinity per resilienza.
3. Crea VolumeSnapshot ricorrente e retention policy.
4. Installa/configura Velero per backup namespace data-prod.
5. Esegui restore selettivo di ConfigMap, Secret e PVC metadata.
6. Simula perdita namespace e ripristina workload entro RTO 15m.
7. Verifica integrita dati post-restore con checksum.
8. Configura reclaimPolicy corretta per volumi critici.
9. Documenta RPO ottenuto in /course/6/rpo-rto-report.txt.
10. Hardening: limita accesso backup bucket con RBAC minimo.

## Risposte guida sintetiche
1. StatefulSet con volumeClaimTemplates e probes sane.
2. PDB minAvailable e topology spread/affinity.
3. SnapshotClass + snapshot schedule (controller/cron).
4. Backup location + credentials + backup command.
5. Restore selettivo con filtri risorsa/namespace.
6. Misura tempi reali da delete a ready.
7. Confronta dump/checksum pre e post.
8. Delete/Retain secondo requisito business.
9. Report con timestamp e deviazioni.
10. SA dedicata e policy principle of least privilege.
