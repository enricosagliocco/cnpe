# CNPE Gaps Lab - Platform APIs and Security

Laboratorio mirato a Platform Architecture, Platform APIs/Self-Service e
Security/Policy Enforcement, pari al 55% del curriculum CNPE.

Rinforza CRD strutturali, API namespaced, composizione di risorse,
multi-tenancy, quote, RBAC, Pod Security, admission policy e audit.

## Avvio

```bash
chmod +x setup-platform-security-lab.sh
./setup-platform-security-lab.sh
```

I file vengono creati in `~/course-platform-security`; Gatekeeper e Crossplane
vengono installati automaticamente. Usare `INSTALL_TOOLS=false` se sono già
presenti.

## Accesso GUI

Importa il kubeconfig corrente in Lens/OpenLens. Le risorse Crossplane e
Gatekeeper sono disponibili in **Custom Resources** e non richiedono
credenziali diverse da quelle Kubernetes.

Il setup crea workload non conformi e starter incompleti per verifiche reali
di CRD, multi-tenancy, NetworkPolicy, RBAC, Pod Security e admission.

## Metodologia comune

Questo lab segue il contratto descritto in `../LAB-METHODOLOGY.md`: 20 task
numerati, `QUESTION.md` ed `evidence.txt` per ogni domanda, soluzioni separate
e verifica esplicita del risultato runtime.

Controllo metodologico offline:

```bash
./
validate-cnpe-gaps-platform-security.sh
```
