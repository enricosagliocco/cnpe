# Gatekeeper and Kyverno CNPE Exam Lab

Laboratorio misto con 20 esercizi pratici di policy enforcement, costruiti
intorno ai pattern che ricorrono nei task hands-on CNPE: completare manifest
parziali, correggere policy guaste, dimostrare un caso ammesso e uno negato e
raccogliere evidenze dal cluster.

Il lab usa:

- Kyverno con le API CEL `policies.kyverno.io/v1`;
- OPA Gatekeeper con ConstraintTemplate, Constraint, audit e mutation;
- Namespace e workload isolati per limitare le interferenze tra domande.

## Avvio

Prerequisiti: Linux, `kubectl`, `helm`, `curl` e un cluster Kubernetes
raggiungibile. Per Minikube:

```bash
chmod +x setup-policy-exam-lab.sh
./setup-policy-exam-lab.sh
```

Il setup installa Gatekeeper e Kyverno, installa la CLI `kyverno` se assente e
crea gli starter in `~/course-policy-exam`.

Per usare un cluster esistente:

```bash
CLUSTER_PROVIDER=existing ./setup-policy-exam-lab.sh
```

Per creare un cluster Kind dedicato:

```bash
./setup-policy-exam-lab-kind.sh
```

Per rigenerare gli starter:

```bash
LAB_FORCE=true ./setup-policy-exam-lab.sh
```

Per non reinstallare i componenti già presenti:

```bash
INSTALL_TOOLS=false ./setup-policy-exam-lab.sh
```

## Struttura

- Q1-Q10: Kyverno CEL, mutation, validation, update e troubleshooting;
- Q11-Q19: Gatekeeper, Rego, match, audit, inventory e mutation;
- Q20: scenario finale con entrambi i motori.

Ogni directory contiene `QUESTION.md`, manifest starter e `evidence.txt`. Le
soluzioni non vengono installate: lo scopo è riprodurre la pressione operativa
dell'esame.

## Comandi utili

```bash
kyverno apply policy.yaml --resource pod.yaml
kubectl get validatingpolicies,mutatingpolicies -A
kubectl get policyreport,clusterpolicyreport -A
kubectl get constrainttemplates,constraints
kubectl -n kyverno logs deploy/kyverno-admission-controller
kubectl -n gatekeeper-system logs deploy/gatekeeper-controller-manager
kubectl -n gatekeeper-system logs deploy/gatekeeper-audit
```

Le policy `Deny` possono interferire con domande successive. Al termine di un
esercizio eliminale oppure passa temporaneamente la Constraint Gatekeeper a
`dryrun`.
