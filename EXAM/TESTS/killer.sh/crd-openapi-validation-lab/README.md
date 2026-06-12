# CNPE CRD OpenAPI Validation Lab

Laboratorio autonomo con 20 prove pratiche in stile esame CNPE dedicate alla
creazione di CustomResourceDefinition Kubernetes con schema OpenAPI.

Il focus e' il dominio CNPE **Platform APIs and Self-Service Capabilities**:

- CRD `apiextensions.k8s.io/v1`;
- schema strutturale OpenAPI v3;
- campi required, enum, default e range;
- stringhe, array, object e mappe;
- pruning e preservazione controllata di campi;
- regole CEL essenziali;
- versioni, status, scale e printer columns;
- verifica con dry-run server-side, `kubectl explain` ed errori API server.

## Avvio

Su un cluster Kubernetes esistente:

```bash
./setup-crd-openapi-validation-lab.sh
```

Con un cluster Kind dedicato:

```bash
./setup-crd-openapi-validation-lab-kind.sh
```

Il materiale viene creato in `~/course-crd-openapi`. Per rigenerarlo:

```bash
LAB_FORCE=true ./setup-crd-openapi-validation-lab.sh
```

Validazione del materiale senza cluster:

```bash
./validate-crd-openapi-validation-lab.sh
```

Fonti ufficiali di riferimento:

- https://www.cncf.io/training/certification/cnpe/
- https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cnpe
- https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/

## Metodologia comune

Questo lab segue il contratto descritto in `../LAB-METHODOLOGY.md`: 20 task
numerati, `QUESTION.md` ed `evidence.txt` per ogni domanda, soluzioni separate
e verifica esplicita del risultato runtime.

Controllo metodologico offline:

```bash
./
validate-crd-openapi-validation-lab.sh
```
