# Le 20 domande dell'esame — Security and Policy Enforcement Lab

Scenario creato da `setup-security-policy-enforcement-lab.sh`. Gli starter
sono in `~/course-security-policy-enforcement/`.

**Vincolo:** non modificare i Deployment `frontend` e `payments`, non
stampare i Secret mTLS, non modificare Kyverno o Tekton core e non concedere
`cluster-admin`. Ogni policy richiede un test consentito e uno negato.

---

### Q1 – Diagnosi comunicazione sicura

Analizza log, Service, endpoint, porte e NetworkPolicy tra frontend e
payments.

### Q2 – Endpoint mTLS

Correggi `01/app-config.yaml` usando
`https://payments.security-apps.svc:8443`.

### Q3 – NetworkPolicy

Consenti ingress TCP 8443 a payments soltanto dai Pod `app=frontend`.

### Q4 – Test autenticazione e isolamento

Verifica frontend consentito, rogue-client bloccato e client senza
certificato rifiutato. Salva in `01/verification.txt`.

---

### Q5 – Audit privilegi auditor

Analizza i privilegi iniziali di `platform-auditor` con
`kubectl auth can-i --list`.

### Q6 – RBAC read-only

Completa `02/rbac.yaml` con get/list/watch per workload, log, policy report e
risorse Tekton richieste.

### Q7 – Privilegi negativi

Verifica diniego su Secret, write workload, RBAC e Node.

### Q8 – Evidenza least privilege

Registra almeno otto test positivi e negativi in `02/auth-check.txt`.

---

### Q9 – Policy audit

Completa `03/audit-policy.yaml` per richiedere label `owner` e
`data-classification` sui Deployment dei Namespace abilitati.

### Q10 – PolicyReport iniziale

Mantieni Audit ed esporta violazioni, rule, messaggio e timestamp in
`03/audit-before.txt`.

### Q11 – Remediation metadata

Aggiungi a `legacy-api` soltanto `owner=platform-team` e
`data-classification=internal`.

### Q12 – Compliance report finale

Attendi la riconciliazione e salva l'assenza di violazioni in
`03/audit-after.txt`.

---

### Q13 – Governance Pod security

Completa il match di `04/governance-policy.yaml` e usa azione Deny.

### Q14 – Security context

Richiedi runAsNonRoot, no privilege escalation, drop ALL e container non
privilegiati.

### Q15 – Image digest

Richiedi immagini referenziate tramite `@sha256:` per ogni container.

### Q16 – Test admission

Verifica `pod-bad` negato, `pod-good` accettato e Namespace non etichettato
escluso. Salva in `04/admission.txt`.

---

### Q17 – Validazione SBOM

Nel Task `compliance-gate`, verifica `SPDXID` e nega package con licenza
`NOASSERTION`.

### Q18 – Vulnerability report

Nega `summary.critical > 0` e produci result `passed` soltanto dopo tutti i
controlli.

### Q19 – Gate di deploy

Condiziona `deploy` a `passed`; esegui prima il caso fallito, poi correggi
SBOM/report ed esegui il caso riuscito.

### Q20 – Verifica finale security

```bash
kubectl -n security-apps get networkpolicy,deploy,pods
kubectl get validatingpolicies
kubectl get policyreports -A
kubectl -n security-pipeline get pipeline,pipelinerun,taskrun
```

Completa `05/pipeline-result.txt` con TaskRun, decisione, blocco iniziale e
log del deploy approvato.
