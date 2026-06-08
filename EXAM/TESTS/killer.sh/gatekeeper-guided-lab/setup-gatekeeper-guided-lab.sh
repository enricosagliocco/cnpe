#!/usr/bin/env bash
set -euo pipefail

GATEKEEPER_VERSION="${GATEKEEPER_VERSION:-v3.22.2}"
COURSE_DIR="${COURSE_DIR:-$HOME/course-gatekeeper-guided}"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"

info() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
die() { echo "[ERR] $*" >&2; exit 1; }

ensure_cluster() {
  if kubectl cluster-info >/dev/null 2>&1; then
    return
  fi

  if command -v minikube >/dev/null 2>&1; then
    info "No reachable cluster; starting Minikube"
    minikube start --cpus=4 --memory=6144
    kubectl cluster-info >/dev/null 2>&1 ||
      die "Minikube started, but kubectl still cannot reach the cluster"
    return
  fi

  die "No reachable Kubernetes cluster and Minikube is not installed"
}

wait_for_gatekeeper_webhook() {
  local attempts=60
  local delay=2
  local check_namespace="gatekeeper-readiness-${RANDOM}-${RANDOM}"
  local attempt

  info "Waiting for the Gatekeeper admission webhook to accept requests"
  for attempt in $(seq 1 "$attempts"); do
    if kubectl create namespace "$check_namespace" \
      --dry-run=server -o name >/dev/null 2>&1; then
      ok "Gatekeeper admission webhook is ready"
      return
    fi
    sleep "$delay"
  done

  die "Gatekeeper admission webhook did not become ready after $((attempts * delay)) seconds"
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$INSTALL_TOOLS" = "true" ]; then
  info "Installing Gatekeeper ${GATEKEEPER_VERSION}; this can take 1-2 minutes"
  kubectl apply -f \
    "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml"
  kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager --timeout=300s
  kubectl -n gatekeeper-system rollout status deploy/gatekeeper-audit --timeout=300s
  wait_for_gatekeeper_webhook
fi

mkdir -p "$COURSE_DIR"
for n in $(seq -w 1 10); do mkdir -p "$COURSE_DIR/$n"; done
for ns in guided-apps guided-prod guided-exempt; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done
kubectl label ns guided-prod policy.gatekeeper/enabled=true --overwrite >/dev/null
kubectl label ns guided-exempt policy.gatekeeper/enabled=false --overwrite >/dev/null

# Q8 needs an existing object that can later be discovered through data.inventory.
if ! kubectl -n guided-apps get ingress inventory-source >/dev/null 2>&1; then
  kubectl apply -f - >/dev/null <<'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: inventory-source
  namespace: guided-apps
spec:
  rules:
    - host: guided.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 80
YAML
fi

cat > "$COURSE_DIR/README.md" <<'MD'
# Metodo di lavoro

Per ogni lezione:

1. leggi prima `example-template.yaml`;
2. separa mentalmente schema, target e Rego;
3. copia il pattern minimo in `template.yaml`;
4. modifica `constraint.yaml`, che contiene valori e scope;
5. applica prima il template;
6. attendi la CRD generata;
7. applica Constraint e workload bad/good;
8. controlla admission e audit.

Regola mentale Rego: un elemento prodotto dall'insieme `violation[...]`
equivale a una violazione. Se l'insieme resta vuoto, la risorsa è valida.
MD

cat > "$COURSE_DIR/01/README.md" <<'MD'
# 01 - Anatomia: Template, CRD e Constraint

Un ConstraintTemplate ha tre responsabilità:

1. `names.kind` crea un nuovo kind Kubernetes;
2. `validation.openAPIV3Schema` definisce i parametri;
3. `targets[].rego` implementa il controllo.

La Constraint è un'istanza: sceglie match, enforcement e valori.

Prendi l'esempio RequiredLabel e trasformalo in RequiredAnnotation con
parametro `annotation`.
MD
cat > "$COURSE_DIR/01/example-template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: guidedrequiredlabel}
spec:
  crd:
    spec:
      names: {kind: GuidedRequiredLabel}
      validation:
        openAPIV3Schema:
          type: object
          properties: {label: {type: string}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package guidedrequiredlabel
        violation[{"msg": msg}] {
          not input.review.object.metadata.labels[input.parameters.label]
          msg := sprintf("Missing label: %s", [input.parameters.label])
        }
YAML
cat > "$COURSE_DIR/01/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: guidedrequiredannotation}
spec:
  crd:
    spec:
      names: {kind: GuidedRequiredAnnotation}
      validation:
        openAPIV3Schema: {} # TODO annotation string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package guidedrequiredannotation
        # TODO copy pattern and change labels to annotations
YAML
cat > "$COURSE_DIR/01/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: GuidedRequiredAnnotation
metadata: {name: require-owner-guided}
spec:
  enforcementAction: deny
  match: {namespaces: [guided-apps], kinds: [{apiGroups: ["apps"], kinds: ["Deployment"]}]}
  parameters: {annotation: owner}
YAML
cat > "$COURSE_DIR/01/bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: owner-bad, namespace: guided-apps}
spec: {selector: {matchLabels: {app: owner-bad}}, template: {metadata: {labels: {app: owner-bad}}, spec: {containers: [{name: app, image: nginx:1-alpine}]}}}
YAML
sed 's/metadata: {name: owner-bad, namespace: guided-apps}/metadata: {name: owner-good, namespace: guided-apps, annotations: {owner: platform}}/; s/owner-bad/owner-good/g' "$COURSE_DIR/01/bad.yaml" > "$COURSE_DIR/01/good.yaml"

cat > "$COURSE_DIR/02/README.md" <<'MD'
# 02 - Lo schema dei parametri

Lo schema protegge la policy prima che Rego venga eseguito.

Costrutti principali:

- `type: string|integer|boolean|array|object`;
- `items` per gli array;
- `required` per campi obbligatori;
- `enum`, `minimum`, `minItems`;
- `additionalProperties: false`.

Prendi lo schema stringa della lezione 01 e trasformalo in array `labels`
obbligatorio con almeno un elemento.
MD
cp "$COURSE_DIR/01/example-template.yaml" "$COURSE_DIR/02/example-template.yaml"
cat > "$COURSE_DIR/02/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: guidedrequiredlabels}
spec:
  crd:
    spec:
      names: {kind: GuidedRequiredLabels}
      validation:
        openAPIV3Schema:
          type: object
          # TODO required labels, array strings, minItems 1, no extras
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package guidedrequiredlabels
        violation[{"msg": msg}] {
          label := input.parameters.labels[_]
          not input.review.object.metadata.labels[label]
          msg := sprintf("Missing label: %s", [label])
        }
YAML
cat > "$COURSE_DIR/02/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: GuidedRequiredLabels
metadata: {name: require-app-team-guided}
spec:
  match: {namespaces: [guided-apps], kinds: [{apiGroups: [""], kinds: ["Pod"]}]}
  parameters: {labels: [app, team]}
YAML
cat > "$COURSE_DIR/02/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: labels-bad, namespace: guided-apps}
spec: {containers: [{name: app, image: nginx:1-alpine}]}
YAML
cat > "$COURSE_DIR/02/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: labels-good, namespace: guided-apps, labels: {app: api, team: platform}}
spec: {containers: [{name: app, image: nginx:1-alpine}]}
YAML

cat > "$COURSE_DIR/03/README.md" <<'MD'
# 03 - Leggere input.review

Percorsi più usati:

- `input.review.object`: oggetto nuovo;
- `input.review.oldObject`: oggetto precedente durante UPDATE;
- `input.review.operation`: CREATE, UPDATE, DELETE;
- `input.review.namespace`, `kind`, `userInfo`.

Usa l'esempio e modifica la policy per controllare
`input.review.object.spec.replicas`. Se il campo è assente, Kubernetes usa una
replica: in Rego gestiscilo con `object.get(obj, "replicas", 1)`.
MD
cat > "$COURSE_DIR/03/example-template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: guidednonodeport}
spec:
  crd: {spec: {names: {kind: GuidedNoNodePort}}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package guidednonodeport
        violation[{"msg": "NodePort forbidden"}] {
          input.review.object.spec.type == "NodePort"
        }
YAML
cat > "$COURSE_DIR/03/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: guidedminimumreplicas}
spec:
  crd:
    spec:
      names: {kind: GuidedMinimumReplicas}
      validation:
        openAPIV3Schema:
          type: object
          properties: {minimum: {type: integer, minimum: 1}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package guidedminimumreplicas
        # TODO object.get spec.replicas and compare to parameter
YAML
cat > "$COURSE_DIR/03/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: GuidedMinimumReplicas
metadata: {name: minimum-two-guided}
spec:
  match: {namespaces: [guided-prod], kinds: [{apiGroups: ["apps"], kinds: ["Deployment"]}]}
  parameters: {minimum: 2}
YAML
cat > "$COURSE_DIR/03/bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: replicas-bad, namespace: guided-prod}
spec:
  selector: {matchLabels: {app: replicas-bad}}
  template:
    metadata: {labels: {app: replicas-bad}}
    spec: {containers: [{name: app, image: nginx:1-alpine}]}
YAML
cat > "$COURSE_DIR/03/good.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: replicas-good, namespace: guided-prod}
spec:
  replicas: 2
  selector: {matchLabels: {app: replicas-good}}
  template:
    metadata: {labels: {app: replicas-good}}
    spec: {containers: [{name: app, image: nginx:1-alpine}]}
YAML

cat > "$COURSE_DIR/04/README.md" <<'MD'
# 04 - Iterare liste e produrre violazioni

In Rego:

```rego
container := input.review.object.spec.containers[_]
```

`[_]` genera una valutazione per ogni elemento. Puoi quindi produrre una
violazione per container.

Modifica lo starter per vietare immagini che non iniziano con uno dei prefissi
in `parameters.repos`. Usa `startswith`.
MD
cat > "$COURSE_DIR/04/example-template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: guidednamedcontainers}
spec:
  crd: {spec: {names: {kind: GuidedNamedContainers}}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package guidednamedcontainers
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          container.name == "latest"
          msg := sprintf("Forbidden container name: %s", [container.name])
        }
YAML
cat > "$COURSE_DIR/04/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: guidedallowedrepos}
spec:
  crd:
    spec:
      names: {kind: GuidedAllowedRepos}
      validation:
        openAPIV3Schema:
          type: object
          properties: {repos: {type: array, items: {type: string}}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package guidedallowedrepos
        # TODO iterate containers and reject when no prefix matches
YAML
cat > "$COURSE_DIR/04/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: GuidedAllowedRepos
metadata: {name: allowed-repos-guided}
spec:
  match: {namespaces: [guided-apps], kinds: [{apiGroups: [""], kinds: ["Pod"]}]}
  parameters: {repos: ["registry.k8s.io/", "ghcr.io/company/"]}
YAML
cat > "$COURSE_DIR/04/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: repo-bad, namespace: guided-apps, labels: {app: repo-bad, team: platform}}
spec: {containers: [{name: web, image: docker.io/library/nginx:latest}]}
YAML
cat > "$COURSE_DIR/04/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: repo-good, namespace: guided-apps, labels: {app: repo-good, team: platform}}
spec: {containers: [{name: app, image: registry.k8s.io/pause:3.10}]}
YAML

cat > "$COURSE_DIR/05/README.md" <<'MD'
# 05 - Set comprehension e label mancanti

I set sono utili per confronti:

```rego
provided := {k | input.review.object.metadata.labels[k]}
required := {k | k := input.parameters.labels[_]}
missing := required - provided
```

Completa lo starter e produci una sola violazione con l'intero set `missing`.
Osserva la differenza rispetto alla lezione 02, che produceva una violazione
per label.
MD
cp "$COURSE_DIR/02/example-template.yaml" "$COURSE_DIR/05/example-template.yaml"
cp "$COURSE_DIR/02/template.yaml" "$COURSE_DIR/05/template.yaml"
sed -i '/package guidedrequiredlabels/,$c\\        package guidedrequiredlabels\\n        # TODO provided, required, missing and one violation' "$COURSE_DIR/05/template.yaml"
cp "$COURSE_DIR/02/constraint.yaml" "$COURSE_DIR/05/constraint.yaml"
cp "$COURSE_DIR/02/bad.yaml" "$COURSE_DIR/05/bad.yaml"
cp "$COURSE_DIR/02/good.yaml" "$COURSE_DIR/05/good.yaml"

cat > "$COURSE_DIR/06/README.md" <<'MD'
# 06 - match: kinds, namespaces, selector ed esclusioni

Il match appartiene alla Constraint, non al Rego.

- `kinds`: tipi;
- `namespaces`: lista statica;
- `excludedNamespaces`: esclusioni;
- `namespaceSelector`: label dei Namespace;
- `labelSelector`: label della risorsa.

Copia il template funzionante della lezione 01. Modifica solo la Constraint:
Deployment nei Namespace con label `policy.gatekeeper/enabled=true`, escluso
`guided-exempt`.
MD
cp "$COURSE_DIR/01/example-template.yaml" "$COURSE_DIR/06/example-template.yaml"
cp "$COURSE_DIR/01/template.yaml" "$COURSE_DIR/06/template.yaml"
cat > "$COURSE_DIR/06/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: GuidedRequiredAnnotation
metadata: {name: selected-owner-guided}
spec:
  enforcementAction: deny
  match:
    kinds: [{apiGroups: ["apps"], kinds: ["Deployment"]}]
    # TODO namespaceSelector enabled=true and exclude guided-exempt
  parameters: {annotation: owner}
YAML
cat > "$COURSE_DIR/06/bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: owner-bad, namespace: guided-prod}
spec:
  replicas: 2
  selector: {matchLabels: {app: owner-bad}}
  template:
    metadata: {labels: {app: owner-bad}}
    spec: {containers: [{name: app, image: nginx:1-alpine}]}
YAML
cp "$COURSE_DIR/01/bad.yaml" "$COURSE_DIR/06/good.yaml"
sed -i 's/namespace: guided-apps/namespace: guided-exempt/; s/owner-bad/exempt-bad/g' "$COURSE_DIR/06/good.yaml"

cat > "$COURSE_DIR/07/README.md" <<'MD'
# 07 - UPDATE e oldObject

Durante UPDATE confronta:

```rego
input.review.object
input.review.oldObject
```

Limita la regola all'operazione UPDATE nel Rego o nel match disponibile.
Completa lo starter per rendere immutabile la label `team`.

Applica nell'ordine `initial.yaml`, `good.yaml` e `bad.yaml`: l'aggiornamento
di `version` deve riuscire, mentre il cambio di `team` deve essere negato.
MD
cat > "$COURSE_DIR/07/example-template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: guidedimmutableowner}
spec:
  crd: {spec: {names: {kind: GuidedImmutableOwner}}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package guidedimmutableowner
        violation[{"msg": "owner is immutable"}] {
          input.review.operation == "UPDATE"
          input.review.object.metadata.labels.owner != input.review.oldObject.metadata.labels.owner
        }
YAML
cat > "$COURSE_DIR/07/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: guidedimmutableteam}
spec:
  crd: {spec: {names: {kind: GuidedImmutableTeam}}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package guidedimmutableteam
        # TODO UPDATE and compare team safely
YAML
cat > "$COURSE_DIR/07/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: GuidedImmutableTeam
metadata: {name: immutable-team-guided}
spec:
  match: {namespaces: [guided-apps], kinds: [{apiGroups: ["apps"], kinds: ["Deployment"]}]}
YAML
cat > "$COURSE_DIR/07/initial.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: immutable
  namespace: guided-apps
  annotations: {owner: platform}
  labels: {team: platform, version: v1}
spec: {selector: {matchLabels: {app: immutable}}, template: {metadata: {labels: {app: immutable}}, spec: {containers: [{name: app, image: nginx:1-alpine}]}}}
YAML
sed 's/version: v1/version: v2/' \
  "$COURSE_DIR/07/initial.yaml" > "$COURSE_DIR/07/good.yaml"
sed 's/team: platform/team: operations/; s/version: v1/version: v2/' \
  "$COURSE_DIR/07/initial.yaml" > "$COURSE_DIR/07/bad.yaml"

cat > "$COURSE_DIR/08/README.md" <<'MD'
# 08 - Inventory: confrontare con risorse esistenti

`data.inventory` contiene oggetti sincronizzati da Gatekeeper. Serve per
unicità e controlli cross-resource.

Pattern:

```rego
other := data.inventory.namespace[ns]["networking.k8s.io/v1"].Ingress[name]
```

Prima abilita la sync dell'Ingress con `config.yaml`. Poi completa il template
per negare un host Ingress già usato, ignorando l'oggetto stesso durante
UPDATE.

Il setup crea `guided-apps/inventory-source` con host `guided.example.com`.
Dopo aver applicato `config.yaml`, attendi che la risorsa sia sincronizzata
prima di provare `bad.yaml`.
MD
cat > "$COURSE_DIR/08/example-template.yaml" <<'YAML'
apiVersion: config.gatekeeper.sh/v1alpha1
kind: Config
metadata: {name: config, namespace: gatekeeper-system}
spec:
  sync:
    syncOnly:
      - {group: "", version: v1, kind: Service}
YAML
cat > "$COURSE_DIR/08/config.yaml" <<'YAML'
apiVersion: config.gatekeeper.sh/v1alpha1
kind: Config
metadata: {name: config, namespace: gatekeeper-system}
spec:
  sync:
    syncOnly: [] # TODO Ingress networking.k8s.io/v1
YAML
cat > "$COURSE_DIR/08/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: guideduniqueingresshost}
spec:
  crd: {spec: {names: {kind: GuidedUniqueIngressHost}}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package guideduniqueingresshost
        # TODO inventory lookup, same host, different object
YAML
cat > "$COURSE_DIR/08/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: GuidedUniqueIngressHost
metadata: {name: unique-host-guided}
spec:
  match: {namespaces: [guided-apps], kinds: [{apiGroups: ["networking.k8s.io"], kinds: ["Ingress"]}]}
YAML
cat > "$COURSE_DIR/08/bad.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: duplicate, namespace: guided-apps}
spec: {rules: [{host: guided.example.com, http: {paths: [{path: /, pathType: Prefix, backend: {service: {name: api, port: {number: 80}}}}]}}]}
YAML
sed 's/name: duplicate/name: unique/; s/guided.example.com/unique.example.com/' "$COURSE_DIR/08/bad.yaml" > "$COURSE_DIR/08/good.yaml"

cat > "$COURSE_DIR/09/README.md" <<'MD'
# 09 - enforcementAction e audit

La Constraint decide l'effetto:

- `dryrun`: audit, nessun blocco;
- `warn`: warning, richiesta ammessa;
- `deny`: blocco admission.

Usa lo stesso template in tre fasi. Parti da dryrun, osserva
`status.violations`, correggi il workload, poi passa a deny.
MD
cp "$COURSE_DIR/01/example-template.yaml" "$COURSE_DIR/09/example-template.yaml"
cp "$COURSE_DIR/01/template.yaml" "$COURSE_DIR/09/template.yaml"
cp "$COURSE_DIR/01/constraint.yaml" "$COURSE_DIR/09/constraint.yaml"
sed -i 's/enforcementAction: deny/enforcementAction: dryrun/' "$COURSE_DIR/09/constraint.yaml"
cp "$COURSE_DIR/01/bad.yaml" "$COURSE_DIR/09/bad.yaml"
cp "$COURSE_DIR/01/good.yaml" "$COURSE_DIR/09/good.yaml"

cat > "$COURSE_DIR/10/README.md" <<'MD'
# 10 - Troubleshooting e composizione finale

Il bundle contiene quattro errori:

1. `metadata.name` del template non coincide col package/kind;
2. schema `parameters.repos` errato;
3. Rego accede a `initContainers` assumendo che esista;
4. Constraint usa un kind o parametro non coerente.

Correggi il bundle, quindi estendilo:

- registry consentiti;
- controllo container e initContainer;
- messaggio con nome e immagine;
- match soltanto `guided-prod`;
- dryrun iniziale, poi deny.

Per ogni correzione scrivi in `report.md`:

- sintomo;
- livello responsabile: YAML, schema CRD, Constraint, Rego, match o audit;
- modifica;
- comando di verifica.
MD
cat > "$COURSE_DIR/10/example-template.yaml" <<'YAML'
# Rileggi gli esempi delle lezioni 02, 04, 06 e 09.
YAML
cat > "$COURSE_DIR/10/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: brokenrepos}
spec:
  crd:
    spec:
      names: {kind: WrongRepos}
      validation:
        openAPIV3Schema:
          type: object
          properties: {repos: {type: string}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package anotherpackage
        violation[{"msg": msg}] {
          c := input.review.object.spec.initContainers[_]
          not startswith(c.image, input.parameters.repos)
          msg := "bad"
        }
YAML
cat > "$COURSE_DIR/10/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: GuidedAllowedRepos
metadata: {name: final-repos-guided}
spec:
  enforcementAction: dryrun
  match: {namespaces: [guided-apps]}
  parameters: {repo: registry.k8s.io/}
YAML
cat > "$COURSE_DIR/10/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: final-bad, namespace: guided-prod}
spec:
  initContainers: [{name: init, image: docker.io/library/busybox:1.36, command: [sh, -c, "true"]}]
  containers: [{name: app, image: registry.k8s.io/pause:3.10}]
YAML
cat > "$COURSE_DIR/10/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: final-good, namespace: guided-prod}
spec: {containers: [{name: app, image: registry.k8s.io/pause:3.10}]}
YAML
touch "$COURSE_DIR/10/report.md"

touch "$COURSE_DIR/.initialized"
echo "Gatekeeper guided lab ready: $COURSE_DIR"
