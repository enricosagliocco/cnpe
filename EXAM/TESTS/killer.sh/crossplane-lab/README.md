# Crossplane Dedicated Lab

Laboratorio autonomo con 20 prove pratiche dedicate alla creazione e gestione
di `CompositeResourceDefinition`, `Composition` Pipeline e composite resource
con Crossplane v2.

La matrice copre:

- XRD cluster-scoped e namespaced;
- schema OpenAPI, required, enum, default, limiti e versioni;
- Composition con Function Patch and Transform;
- uso esplicito di `FromCompositeFieldPath` e `ToCompositeFieldPath`;
- patch semplici, PatchSet, combine, transform e patch verso lo status;
- readiness check e propagazione dei metadata;
- selezione della Composition e CompositionRevision automatiche/manuali;
- update, pausa, riconciliazione e troubleshooting;
- simulazione completa da manifest vuoti.

Gli scenari usano soltanto risorse Kubernetes locali e non richiedono account
cloud.

## Avvio

Prerequisiti: Linux o WSL, `kubectl`, `helm` e un cluster Kubernetes.

```bash
chmod +x setup-crossplane-lab.sh validate-crossplane-lab.sh
./setup-crossplane-lab.sh
```

Per creare automaticamente un cluster Kind:

```bash
./setup-crossplane-lab-kind.sh
```

Il materiale viene generato in `~/course-crossplane`. Ogni directory contiene
`xrd.yaml`, `composition.yaml`, `xr.yaml`, `QUESTION.md` ed `evidence.txt`.
Alcune prove includono file aggiuntivi intenzionalmente corretti o errati.

Il setup installa Crossplane e `function-patch-and-transform`. Per rigenerare
una directory esistente:

```bash
LAB_FORCE=true ./setup-crossplane-lab.sh
```

## Validazione senza cluster

Il validatore esegue il generatore in una directory temporanea senza installare
Crossplane:

```bash
./validate-crossplane-lab.sh
```

La stessa modalita' e' disponibile direttamente:

```bash
COURSE_DIR=/tmp/course-crossplane LAB_SKIP_INSTALL=true \
  ./setup-crossplane-lab.sh
```

Per la GUI puoi usare Lens/OpenLens con il kubeconfig corrente. XRD,
Composition, CompositionRevision, XR, eventi e risorse composte sono visibili
tra le Custom Resources.

## Metodologia comune

Questo lab segue il contratto descritto in `../LAB-METHODOLOGY.md`: 20 task
numerati, `QUESTION.md` ed `evidence.txt` per ogni domanda, soluzioni separate
e verifica esplicita del risultato runtime.

Controllo metodologico offline:

```bash
./
validate-crossplane-lab.sh
```
