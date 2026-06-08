# CNPE Security and Policy Enforcement Lab

Scenario creato da `setup-security-policy-enforcement-lab.sh`. Gli starter
sono in `~/course-security-policy-enforcement/`.

## Vincoli d'esame

- Non modificare i Deployment `frontend` e `payments`.
- Non leggere o stampare il contenuto dei Secret mTLS.
- Non modificare i componenti core nei Namespace `kyverno` e
  `tekton-pipelines`.
- Non concedere privilegi `cluster-admin`.
- Ogni policy deve essere verificata con un caso consentito e uno negato.

Sono consentite modifiche a ConfigMap, NetworkPolicy, RBAC, policy Kyverno,
Pipeline, PipelineRun e metadati dei workload non conformi.

---

### Q1 – Comunicazione service-to-service sicura

Nel Namespace `security-apps`, `frontend` deve chiamare `payments` tramite
mTLS. Il backend richiede già un certificato client firmato dalla CA del lab,
ma il frontend usa un endpoint errato e una NetworkPolicy blocca il traffico.

1. Analizza log dei Pod, Service, endpoint, porte e NetworkPolicy.
2. Correggi `01/app-config.yaml` usando:
   `https://payments.security-apps.svc:8443`.
3. Completa `01/networkpolicy.yaml` consentendo ingress TCP 8443 verso i Pod
   `app=payments` soltanto dai Pod `app=frontend`.
4. Applica i file ed elimina soltanto il Pod frontend per ricaricare la
   ConfigMap.
5. Verifica nei log frontend la risposta `payments ok`.
6. Dimostra che:
   - da `rogue-client`, il traffico verso `payments:8443` è bloccato dalla
     NetworkPolicy;
   - da `unauthenticated-client`, la rete consente il collegamento ma il
     backend rifiuta la richiesta priva di certificato client.
7. Salva prove e comandi in `01/verification.txt`.

Non modificare certificati, Secret, Deployment o configurazione nginx.

---

### Q2 – RBAC least privilege

Il ServiceAccount `platform-auditor` dispone inizialmente di privilegi
illimitati.

Correggi `02/rbac.yaml` affinché possa:

- leggere `pods`, `pods/log`, `services`, `endpoints`, `configmaps` e
  `deployments`;
- leggere `policyreports.wgpolicyk8s.io` e
  `clusterpolicyreports.wgpolicyk8s.io`;
- leggere `pipelines`, `pipelineruns`, `tasks` e `taskruns`;
- operare in sola lettura con `get`, `list`, `watch`.

Non deve poter:

- leggere Secret;
- creare, aggiornare o eliminare workload;
- modificare RBAC;
- accedere ai Node.

Applica il file e registra in `02/auth-check.txt` almeno otto verifiche
`kubectl auth can-i`, includendo test positivi nei Namespace `security-apps`
e `security-pipeline` e test negativi su Secret, RoleBinding e Node.

---

### Q3 – Audit trail e compliance report

Il Deployment `legacy-api` non contiene le label `owner` e
`data-classification`. La policy starter è in modalità Audit ma la sua
espressione accetta tutto.

1. Completa `03/audit-policy.yaml`.
2. Limita la policy ai Namespace con label
   `security.cnpe.io/policy=enabled`.
3. Richiedi entrambe le label sui Deployment.
4. Mantieni `validationActions: Audit`.
5. Applica la policy e attendi la generazione del PolicyReport.
6. Esporta violazioni, messaggio, policy, rule e timestamp in
   `03/audit-before.txt`.
7. Correggi soltanto i metadati del Deployment `legacy-api`:
   - `owner=platform-team`;
   - `data-classification=internal`.
8. Attendi la riconciliazione dei report e salva lo stato senza violazioni in
   `03/audit-after.txt`.

La modalità Audit non deve bloccare nuove risorse durante questa domanda.

---

### Q4 – Admission controller e governance

La policy `enforce-pod-security-and-digests` deve impedire l'ammissione di Pod
non conformi nel Namespace `security-apps`.

Completa `04/governance-policy.yaml`:

1. limita il match ai Namespace etichettati per le policy;
2. usa azione `Deny`;
3. richiedi `spec.securityContext.runAsNonRoot == true`;
4. richiedi per ogni container:
   - immagine referenziata tramite digest `@sha256:`;
   - `allowPrivilegeEscalation == false`;
   - capability `ALL` rimossa;
5. nega container privilegiati.

Verifica:

- `04/pod-bad.yaml` rifiutato dal server API;
- `04/pod-good.yaml` accettato;
- un Pod in un Namespace non etichettato non è incluso nel match.

Salva output admission ed eventi in `04/admission.txt`.

---

### Q5 – Security gate nella pipeline

La Pipeline Tekton `secure-deployment` copia SBOM e scan report nel workspace,
ma il gate approva sempre e il task `deploy` non ha una condizione.

Completa `05/pipeline.yaml` affinché `compliance-gate`:

1. verifichi la presenza di `SPDXID` nell'SBOM;
2. fallisca se almeno un package ha licenza `NOASSERTION`;
3. fallisca se `summary.critical` nel report di scansione è maggiore di zero;
4. scriva `passed` nel result `decision` soltanto quando tutti i controlli
   riescono;
5. faccia eseguire `deploy` soltanto quando il result vale `passed`.

Esegui due prove:

1. Con gli input iniziali, il PipelineRun deve fallire e `deploy` non deve
   partire.
2. Correggi `05/sbom.json` con una licenza valida e porta
   `summary.critical` a zero in `05/scan-report.json`; aggiorna il ConfigMap
   `security-inputs` e crea un nuovo PipelineRun. Deve terminare con
   `Succeeded=True` e log `deployment approved`.

Salva stato dei TaskRun, result, motivazione del blocco e log finali in
`05/pipeline-result.txt`.

---

### Verifica finale

```bash
kubectl -n security-apps get networkpolicy,deploy,pods
kubectl auth can-i --as=system:serviceaccount:security-platform:platform-auditor \
  get deployments -n security-apps
kubectl get validatingpolicies
kubectl get policyreports -A
kubectl -n security-pipeline get pipeline,pipelinerun,taskrun
```

La prova è completa quando mTLS e isolamento di rete funzionano, l'RBAC è
least privilege, i report di audit mostrano la remediation, l'admission
controller blocca i Pod non conformi e la pipeline impedisce il deploy di
artefatti non conformi.
