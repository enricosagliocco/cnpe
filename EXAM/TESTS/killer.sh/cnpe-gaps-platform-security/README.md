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
