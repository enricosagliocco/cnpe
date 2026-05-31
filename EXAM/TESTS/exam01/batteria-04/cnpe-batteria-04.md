# CNPE Batteria 04 - Supply Chain Security e Compliance CI/CD

Focus strumenti: Tekton, Trivy, Syft, Cosign, Kyverno verifyImages, SBOM, provenance.

## Domande (10)
1. Estendi pipeline Tekton con stage sbom-generate prima della build image finale.
2. Aggiungi scan Trivy e fallisci su HIGH/CRITICAL > 0.
3. Firma image con Cosign keyless o key-pair locale.
4. Pubblica sbom.json e scan-report.txt come artifact pipeline.
5. Applica Kyverno policy verifyImages che accetta solo immagini firmate.
6. Blocca deployment con tag latest via policy.
7. Aggiungi attestazione provenance e valida in admission.
8. Implementa gate manuale per promozione prod solo su compliance PASS.
9. Genera audit trail pipeline in /course/4/compliance-audit.txt.
10. Esegui test: immagine non firmata deve essere rifiutata.

## Risposte guida sintetiche
1. Task Tekton con syft packages -o json > sbom.json.
2. Task Trivy con exit-code 1 su severita HIGH,CRITICAL.
3. cosign sign image:tag e verifica digest firmato.
4. Usa workspaces/results o volume condiviso per artifact.
5. ClusterPolicy Kyverno verifyImages con attestations opzionali.
6. Regola deny su pattern :latest.
7. Includi predicate provenance e controllo condizioni.
8. Task finale condizionale su output scan/compliance.
9. Colleziona logs e status pipelinerun in file dedicato.
10. kubectl apply test manifest non conforme -> deny atteso.
