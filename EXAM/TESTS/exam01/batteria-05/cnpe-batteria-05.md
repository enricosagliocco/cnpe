# CNPE Batteria 05 - Multi-Cluster GitOps e Fleet Management

Focus strumenti: FluxCD, Argo CD ApplicationSet, Kustomize, Helm, cluster bootstrap.

## Domande (10)
1. Bootstrap Flux su due cluster context diversi (west/east).
2. Crea GitRepository+Kustomization per overlay regionali.
3. Implementa promotion dev->staging->prod via branch strategy.
4. Usa health checks e dipendenze tra Kustomization.
5. Configura Argo ApplicationSet cluster generator per deploy fleet-app.
6. Applica drift manuale e dimostra auto-heal in entrambi i cluster.
7. Introduci HelmRelease con values diversi per regione.
8. Gestisci secret con SOPS o equivalente encrypted workflow.
9. Esegui rollback GitOps a commit precedente senza kubectl patch manuali.
10. Scrivi runbook fleet in /course/5/multi-cluster-runbook.md.

## Risposte guida sintetiche
1. Verifica contexts kubectl e install controller GitOps su entrambi.
2. Layout repo con base + overlays/west,east.
3. Merge controllato e sync automato su env successivo.
4. dependsOn/healthChecks per ordine convergenza.
5. ApplicationSet genera app per ogni cluster registrato.
6. Replica change live e osserva reconcile.
7. Helm chart unico, values per cluster.
8. Decrypt solo in controller path autorizzato.
9. git revert + reconcile forzata.
10. Include SLO di convergence e failure playbook.
