#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-kyverno-guided}"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
KYVERNO_VERSION="${KYVERNO_VERSION:-3.8.1}"
CLI_VERSION="${CLI_VERSION:-1.18.1}"
export PATH="$HOME/.local/bin:$PATH"

die() { echo "[ERR] $*" >&2; exit 1; }

ensure_cluster() {
  if kubectl cluster-info >/dev/null 2>&1; then
    return
  fi
  if command -v minikube >/dev/null 2>&1; then
    echo "[INFO] No reachable cluster; starting Minikube"
    minikube start --cpus=4 --memory=6144
    kubectl cluster-info >/dev/null 2>&1 ||
      die "Minikube started, but kubectl still cannot reach the cluster"
    return
  fi
  die "No reachable Kubernetes cluster and Minikube is not installed"
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster
if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$INSTALL_TOOLS" = "true" ]; then
  command -v helm >/dev/null || { echo "helm is required"; exit 1; }
  helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace \
    --version "$KYVERNO_VERSION" --wait
  kubectl -n kyverno rollout status deploy/kyverno-admission-controller --timeout=300s
  kubectl -n kyverno rollout status deploy/kyverno-background-controller --timeout=300s
fi

if ! command -v kyverno >/dev/null; then
  command -v curl >/dev/null || { echo "curl is required"; exit 1; }
  arch="$(uname -m)"
  case "$arch" in x86_64) arch=x86_64 ;; aarch64|arm64) arch=arm64 ;; *) exit 1 ;; esac
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/kyverno/kyverno/releases/download/v${CLI_VERSION}/kyverno-cli_v${CLI_VERSION}_linux_${arch}.tar.gz" |
    tar -xz -C "$tmp"
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$tmp/kyverno" "$HOME/.local/bin/kyverno"
  rm -rf "$tmp"
fi

mkdir -p "$COURSE_DIR"
for n in $(seq -w 1 10); do mkdir -p "$COURSE_DIR/$n"; done
for ns in guided-apps guided-prod; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

cat > "$COURSE_DIR/README.md" <<'MD'
# Metodo di lavoro

Per ogni lezione:

1. leggi `example.yaml` dall'alto verso il basso;
2. individua il blocco indicato nel README;
3. copia soltanto quel pattern in `policy.yaml`;
4. cambia risorsa, campo o valore richiesto;
5. prova localmente:
   `kyverno apply policy.yaml --resource bad.yaml`;
6. applica la policy e prova admission con `kubectl apply`.

Regola mentale CEL: l'espressione deve restituire `true` quando la risorsa è
valida. Se restituisce `false`, Kyverno esegue l'azione configurata.

Le lezioni sono isolate. Dopo i test admission elimina la policy applicata,
salvo quando una lezione richiede esplicitamente di riutilizzarla.
MD

cat > "$COURSE_DIR/01/README.md" <<'MD'
# 01 - Anatomia di una ValidatingPolicy

Impara i quattro blocchi:

- `metadata.name`: identità della policy;
- `validationActions`: `Deny`, `Warn` o `Audit`;
- `matchConstraints.resourceRules`: quali richieste intercettare;
- `validations`: espressione CEL e messaggio.

Prendi da `example.yaml` il pattern completo. In `policy.yaml` cambia la
risorsa da ConfigMap a Namespace e il campo richiesto da label `owner` ad
annotation `project-name`.

Sintassi chiave:

```cel
"'chiave' in object.metadata.?annotations.orValue({})"
```

`?annotations` rende il campo opzionale; `orValue({})` usa una mappa vuota se
le annotation non esistono.
MD
cat > "$COURSE_DIR/01/example.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: {name: example-owner}
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["configmaps"]
  validations:
    - message: "ConfigMap requires owner"
      expression: "'owner' in object.metadata.?labels.orValue({})"
YAML
cat > "$COURSE_DIR/01/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: {name: require-project-name}
spec:
  validationActions: [] # TODO
  matchConstraints:
    resourceRules: [] # TODO Namespace CREATE
  validations:
    - message: "Namespace requires project-name"
      expression: "true" # TODO
YAML
cat > "$COURSE_DIR/01/bad.yaml" <<'YAML'
apiVersion: v1
kind: Namespace
metadata: {name: guided-bad}
YAML
cat > "$COURSE_DIR/01/good.yaml" <<'YAML'
apiVersion: v1
kind: Namespace
metadata: {name: guided-good, annotations: {project-name: platform}}
YAML

cat > "$COURSE_DIR/02/README.md" <<'MD'
# 02 - resourceRules: gruppo, versione, operazione e risorsa

Una rule è un filtro AND:

- `apiGroups`: `""` per core API, `apps` per Deployment;
- `apiVersions`: normalmente `v1`;
- `operations`: `CREATE`, `UPDATE`, `DELETE`, `CONNECT`;
- `resources`: nome plurale minuscolo.

Copia la struttura da `example.yaml`, poi modifica `policy.yaml` per
intercettare Deployment in CREATE e UPDATE. Richiedi `spec.replicas >= 2`.

Campi opzionali:

```cel
object.spec.?replicas.orValue(1) >= 2
```
MD
cat > "$COURSE_DIR/02/example.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: {name: example-services}
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["services"]
  validations:
    - {message: "NodePort forbidden", expression: "object.spec.?type.orValue('ClusterIP') != 'NodePort'"}
YAML
cat > "$COURSE_DIR/02/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: {name: minimum-replicas-guided}
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules: [] # TODO apps/v1 deployments CREATE+UPDATE
  validations:
    - message: "Deployment requires at least 2 replicas"
      expression: "true" # TODO
YAML
cat > "$COURSE_DIR/02/bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: one, namespace: guided-apps}
spec: {replicas: 1, selector: {matchLabels: {app: one}}, template: {metadata: {labels: {app: one}}, spec: {containers: [{name: app, image: nginx:1-alpine}]}}}
YAML
sed 's/name: one/name: two/g; s/app: one/app: two/g; s/replicas: 1/replicas: 2/' "$COURSE_DIR/02/bad.yaml" > "$COURSE_DIR/02/good.yaml"

cat > "$COURSE_DIR/03/README.md" <<'MD'
# 03 - Collezioni CEL: all(), exists() e map()

Le liste Kubernetes sono liste CEL.

- `list.all(x, condizione)`: ogni elemento deve rispettare la condizione;
- `list.exists(x, condizione)`: almeno un elemento deve rispettarla;
- `list.map(x, valore)`: trasforma gli elementi.

Copia il pattern `all()` dall'esempio. Modificalo per richiedere a ogni
container CPU request e memory request.

Accesso a chiavi con punto:

```cel
"'cpu' in c.resources.?requests.orValue({})"
```
MD
cat > "$COURSE_DIR/03/example.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: {name: example-images}
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules: [{apiGroups: [""], apiVersions: ["v1"], operations: ["CREATE"], resources: ["pods"]}]
  validations:
    - message: "All images require a tag"
      expression: "object.spec.containers.all(c, c.image.contains(':'))"
YAML
cat > "$COURSE_DIR/03/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: {name: require-requests-guided}
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules: [{apiGroups: [""], apiVersions: ["v1"], operations: ["CREATE"], resources: ["pods"]}]
  validations:
    - message: "Every container requires CPU and memory requests"
      expression: "true" # TODO all()
YAML
cat > "$COURSE_DIR/03/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: requests-bad, namespace: guided-apps}
spec: {containers: [{name: app, image: nginx:1-alpine}]}
YAML
cat > "$COURSE_DIR/03/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: requests-good, namespace: guided-apps}
spec:
  containers:
    - name: app
      image: nginx:1-alpine
      resources: {requests: {cpu: 10m, memory: 16Mi}}
YAML

cat > "$COURSE_DIR/04/README.md" <<'MD'
# 04 - matchConditions: applicare una regola solo quando serve

`resourceRules` sceglie il tipo di oggetto. `matchConditions` restringe
ulteriormente usando CEL.

Esempio: eseguire la validazione soltanto se la label environment vale
production.

```cel
object.metadata.?labels.orValue({}).get('environment', '') == 'production'
```

Modifica lo starter: la regola delle 2 repliche deve ignorare development.
MD
cp "$COURSE_DIR/02/example.yaml" "$COURSE_DIR/04/example.yaml"
cp "$COURSE_DIR/02/policy.yaml" "$COURSE_DIR/04/policy.yaml"
cp "$COURSE_DIR/02/bad.yaml" "$COURSE_DIR/04/bad.yaml"
cp "$COURSE_DIR/02/bad.yaml" "$COURSE_DIR/04/good.yaml"
sed -i 's/name: one/name: dev-one/g; s/app: one/app: dev-one/g' "$COURSE_DIR/04/good.yaml"
sed -i '/metadata:/s/$//' "$COURSE_DIR/04/bad.yaml"
sed -i 's/metadata: {name: one, namespace: guided-apps}/metadata: {name: one, namespace: guided-apps, labels: {environment: production}}/' "$COURSE_DIR/04/bad.yaml"
sed -i 's/metadata: {name: dev-one, namespace: guided-apps}/metadata: {name: dev-one, namespace: guided-apps, labels: {environment: development}}/' "$COURSE_DIR/04/good.yaml"

cat > "$COURSE_DIR/05/README.md" <<'MD'
# 05 - NamespacedValidatingPolicy

Una `ValidatingPolicy` è cluster-scoped. Una `NamespacedValidatingPolicy`
vive in un Namespace e governa soltanto quel Namespace.

Prendi l'esempio cluster-scoped e modifica:

1. `kind`;
2. `metadata.namespace`;
3. nessun filtro namespace nella CEL.

Lo starter deve richiedere annotation `owner` ai ConfigMap di `guided-apps`,
senza influire su `guided-prod`.
MD
cp "$COURSE_DIR/01/example.yaml" "$COURSE_DIR/05/example.yaml"
cat > "$COURSE_DIR/05/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedValidatingPolicy
metadata: {name: require-owner-guided, namespace: guided-apps}
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules: [{apiGroups: [""], apiVersions: ["v1"], operations: ["CREATE"], resources: ["configmaps"]}]
  validations:
    - message: "ConfigMap requires owner"
      expression: "true" # TODO
YAML
cat > "$COURSE_DIR/05/bad.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata: {name: owner-bad, namespace: guided-apps}
data: {key: value}
YAML
cat > "$COURSE_DIR/05/good.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata: {name: owner-good, namespace: guided-apps, annotations: {owner: platform}}
data: {key: value}
YAML

cat > "$COURSE_DIR/06/README.md" <<'MD'
# 06 - Anatomia di una MutatingPolicy

Una mutation `ApplyConfiguration` descrive il frammento che vuoi aggiungere.
Non è una validazione: l'espressione restituisce un oggetto patch.

```cel
Object{
  metadata: Object.metadata{
    labels: Object.metadata.labels{team: "platform"}
  }
}
```

Copia il pattern e aggiungi nello stesso oggetto anche annotation
`training: guided`.
MD
cat > "$COURSE_DIR/06/example.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedMutatingPolicy
metadata: {name: example-team, namespace: guided-apps}
spec:
  matchConstraints:
    resourceRules: [{apiGroups: [""], apiVersions: ["v1"], operations: ["CREATE"], resources: ["pods"]}]
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: 'Object{metadata: Object.metadata{labels: Object.metadata.labels{team: "platform"}}}'
YAML
cat > "$COURSE_DIR/06/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedMutatingPolicy
metadata: {name: add-training-metadata, namespace: guided-apps}
spec:
  matchConstraints:
    resourceRules: [{apiGroups: [""], apiVersions: ["v1"], operations: ["CREATE"], resources: ["pods"]}]
  mutations: [] # TODO copy and extend example
YAML
cat > "$COURSE_DIR/06/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: mutation-demo, namespace: guided-apps}
spec: {containers: [{name: app, image: registry.k8s.io/pause:3.10}]}
YAML
cp "$COURSE_DIR/06/bad.yaml" "$COURSE_DIR/06/good.yaml"

cat > "$COURSE_DIR/07/README.md" <<'MD'
# 07 - Mutation condizionale

Una patch non deve sovrascrivere valori scelti dall'utente. Aggiungi una
condizione alla mutation:

```cel
!('environment' in object.metadata.?labels.orValue({}))
```

Prendi la mutation della lezione 06 e aggiungi `matchConditions` alla singola
mutation. Verifica un Pod senza label e uno con `environment: production`.
MD
cp "$COURSE_DIR/06/example.yaml" "$COURSE_DIR/07/example.yaml"
cp "$COURSE_DIR/06/policy.yaml" "$COURSE_DIR/07/policy.yaml"
cp "$COURSE_DIR/06/bad.yaml" "$COURSE_DIR/07/bad.yaml"
cat > "$COURSE_DIR/07/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: preserve-production, namespace: guided-apps, labels: {environment: production}}
spec: {containers: [{name: app, image: registry.k8s.io/pause:3.10}]}
YAML

cat > "$COURSE_DIR/08/README.md" <<'MD'
# 08 - UPDATE e oldObject

Durante UPDATE:

- `object` è la nuova versione;
- `oldObject` è la versione esistente.

Per rendere una label immutabile:

```cel
object.metadata.?labels.orValue({}).get('team', '') ==
oldObject.metadata.?labels.orValue({}).get('team', '')
```

Completa lo starter e prova una patch alla label team e una alla label version.
MD
cat > "$COURSE_DIR/08/example.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: {name: example-immutable}
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules: [{apiGroups: ["apps"], apiVersions: ["v1"], operations: ["UPDATE"], resources: ["deployments"]}]
  validations:
    - {message: "owner is immutable", expression: "object.metadata.?labels.orValue({}).get('owner', '') == oldObject.metadata.?labels.orValue({}).get('owner', '')"}
YAML
cat > "$COURSE_DIR/08/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: {name: immutable-team-guided}
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules: [{apiGroups: ["apps"], apiVersions: ["v1"], operations: ["UPDATE"], resources: ["deployments"]}]
  validations:
    - message: "team is immutable"
      expression: "true" # TODO object vs oldObject
YAML
cat > "$COURSE_DIR/08/bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: immutable, namespace: guided-apps, labels: {team: platform, version: v1}}
spec: {selector: {matchLabels: {app: immutable}}, template: {metadata: {labels: {app: immutable}}, spec: {containers: [{name: app, image: nginx:1-alpine}]}}}
YAML
cp "$COURSE_DIR/08/bad.yaml" "$COURSE_DIR/08/good.yaml"

cat > "$COURSE_DIR/09/README.md" <<'MD'
# 09 - Audit, Deny e PolicyReport

La stessa CEL può essere usata in fasi diverse:

- `Audit`: segnala risorse esistenti;
- `Warn`: ammette ma avvisa;
- `Deny`: blocca.

Completa la CEL per label `cost-center`, applica prima in Audit e osserva
PolicyReport. Correggi il workload, poi cambia a Deny e prova una nuova
risorsa non conforme.
MD
cat > "$COURSE_DIR/09/example.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: {name: example-audit}
spec:
  validationActions: [Audit]
  matchConstraints:
    resourceRules: [{apiGroups: ["apps"], apiVersions: ["v1"], operations: ["CREATE", "UPDATE"], resources: ["deployments"]}]
  validations:
    - {message: "owner required", expression: "'owner' in object.metadata.?labels.orValue({})"}
YAML
cat > "$COURSE_DIR/09/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: {name: require-cost-center-guided}
spec:
  validationActions: [Audit]
  matchConstraints:
    resourceRules: [{apiGroups: ["apps"], apiVersions: ["v1"], operations: ["CREATE", "UPDATE"], resources: ["deployments"]}]
  validations:
    - message: "cost-center required"
      expression: "true" # TODO
YAML
cp "$COURSE_DIR/02/bad.yaml" "$COURSE_DIR/09/bad.yaml"
cp "$COURSE_DIR/02/good.yaml" "$COURSE_DIR/09/good.yaml"

cat > "$COURSE_DIR/10/README.md" <<'MD'
# 10 - Comporre una policy completa

Obiettivo finale: parti dagli esempi delle lezioni precedenti e crea:

1. ValidatingPolicy sui Pod di `guided-prod`;
2. immagini solo `registry.k8s.io/`;
3. ogni container con CPU/memory request;
4. `runAsNonRoot: true`;
5. MutatingPolicy che aggiunge `managed-by: kyverno` senza sovrascriverla.

Scrivi accanto a ogni espressione un commento che spieghi:

- tipo del dato (`map`, `list`, `string`, `bool`);
- perché usi `?campo`, `orValue`, `all` o `matchConditions`;
- quando l'espressione restituisce true.

Non copiare una soluzione intera: combina i piccoli pattern già studiati.
MD
cp "$COURSE_DIR/03/example.yaml" "$COURSE_DIR/10/example.yaml"
cat > "$COURSE_DIR/10/policy.yaml" <<'YAML'
# TODO ValidatingPolicy + NamespacedMutatingPolicy
YAML
cat > "$COURSE_DIR/10/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: final-bad, namespace: guided-prod}
spec: {containers: [{name: app, image: docker.io/library/nginx:latest}]}
YAML
cat > "$COURSE_DIR/10/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: final-good, namespace: guided-prod}
spec:
  securityContext: {runAsNonRoot: true}
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
      resources: {requests: {cpu: 10m, memory: 16Mi}}
YAML

touch "$COURSE_DIR/.initialized"
echo "Kyverno guided lab ready: $COURSE_DIR"
