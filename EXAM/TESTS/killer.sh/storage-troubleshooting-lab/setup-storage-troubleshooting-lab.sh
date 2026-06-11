#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-storage-troubleshooting}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$LAB_FORCE" = "true" ]; then
  info "Removing previously generated files"
  rm -rf "$COURSE_DIR"
fi

for number in $(seq -w 1 20); do
  mkdir -p "$COURSE_DIR/q$number"
  touch "$COURSE_DIR/q$number/evidence.txt"
  cat > "$COURSE_DIR/q$number/namespace.yaml" <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: storage-q${number}
YAML
done

# Q1: wrong StorageClass.
cat > "$COURSE_DIR/q01/incident.yaml" <<'YAML'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-q01-manual
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q01-report
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: storage-q01-manual
  hostPath:
    path: /tmp/storage-q01
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: report-data
  namespace: storage-q01
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: storage-q01-mannual
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: reporting
  namespace: storage-q01
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo ready >/data/status; sleep 3600"]
      volumeMounts: [{name: data, mountPath: /data}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: report-data}
YAML

# Q2: selector mismatch.
cat > "$COURSE_DIR/q02/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q02-catalog
  labels:
    storage.cnpe.io/application: inventory
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  hostPath:
    path: /tmp/storage-q02
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: catalog-data
  namespace: storage-q02
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  selector:
    matchLabels:
      storage.cnpe.io/application: catalog
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: catalog
  namespace: storage-q02
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "touch /data/ready; sleep 3600"]
      volumeMounts: [{name: data, mountPath: /data}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: catalog-data}
YAML

# Q3: insufficient PV capacity.
cat > "$COURSE_DIR/q03/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q03-ledger
spec:
  capacity: {storage: 512Mi}
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  hostPath:
    path: /tmp/storage-q03
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ledger-data
  namespace: storage-q03
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: ledger
  namespace: storage-q03
spec:
  containers:
    - name: database
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts: [{name: data, mountPath: /var/lib/ledger}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: ledger-data}
YAML

# Q4: incompatible access mode.
cat > "$COURSE_DIR/q04/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q04-media
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteMany]
  storageClassName: ""
  hostPath:
    path: /tmp/storage-q04
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: media-data
  namespace: storage-q04
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: media
  namespace: storage-q04
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts: [{name: data, mountPath: /media}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: media-data}
YAML

# Q5: different static StorageClasses.
cat > "$COURSE_DIR/q05/incident.yaml" <<'YAML'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-q05-silver
provisioner: kubernetes.io/no-provisioner
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-q05-gold
provisioner: kubernetes.io/no-provisioner
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q05-billing
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: storage-q05-silver
  hostPath:
    path: /tmp/storage-q05
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: billing-data
  namespace: storage-q05
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: storage-q05-gold
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: billing
  namespace: storage-q05
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts: [{name: data, mountPath: /data}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: billing-data}
YAML

# Q6: PVC pre-bound to a missing PV.
cat > "$COURSE_DIR/q06/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q06-archive
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  hostPath:
    path: /tmp/storage-q06
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: archive-data
  namespace: storage-q06
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  volumeName: storage-q06-archive-old
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: archive
  namespace: storage-q06
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts: [{name: data, mountPath: /archive}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: archive-data}
YAML

# Q7: workload references a missing PVC.
cat > "$COURSE_DIR/q07/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q07-processor
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  hostPath:
    path: /tmp/storage-q07
    type: DirectoryOrCreate
---
apiVersion: v1
kind: Pod
metadata:
  name: processor
  namespace: storage-q07
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo processed >/work/result; sleep 3600"]
      volumeMounts: [{name: work, mountPath: /work}]
  volumes:
    - name: work
      persistentVolumeClaim:
        claimName: processor-data
YAML
cat > "$COURSE_DIR/q07/claim.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: processor-data
  namespace: storage-q07
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests: {storage: 1Gi}
YAML

# Q8: missing ConfigMap.
cat > "$COURSE_DIR/q08/incident.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: config-reader
  namespace: storage-q08
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "cat /etc/app/mode; sleep 3600"]
      volumeMounts: [{name: config, mountPath: /etc/app}]
  volumes:
    - name: config
      configMap:
        name: application-config
YAML
cat > "$COURSE_DIR/q08/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: application-settings
  namespace: storage-q08
data:
  mode: production
YAML

# Q9: missing Secret.
cat > "$COURSE_DIR/q09/incident.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: credentials-reader
  namespace: storage-q09
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "test -s /credentials/token; sleep 3600"]
      volumeMounts: [{name: credentials, mountPath: /credentials, readOnly: true}]
  volumes:
    - name: credentials
      secret:
        secretName: api-credentials
YAML
cat > "$COURSE_DIR/q09/secret.yaml" <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: api-credential
  namespace: storage-q09
type: Opaque
stringData:
  token: cnpe-training-token
YAML

# Q10: ConfigMap exists but requested key does not.
cat > "$COURSE_DIR/q10/incident.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
  namespace: storage-q10
data:
  config.yaml: |
    mode: production
---
apiVersion: v1
kind: Pod
metadata:
  name: settings-reader
  namespace: storage-q10
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "cat /etc/app/application.yaml; sleep 3600"]
      volumeMounts: [{name: settings, mountPath: /etc/app}]
  volumes:
    - name: settings
      configMap:
        name: app-settings
        items:
          - key: application.yaml
            path: application.yaml
YAML

# Q11: writable workload receives a read-only mount.
cat > "$COURSE_DIR/q11/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q11-writer
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  hostPath:
    path: /tmp/storage-q11
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: writer-data
  namespace: storage-q11
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: writer
  namespace: storage-q11
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo initialized >/data/status; sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
          readOnly: true
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: writer-data}
YAML

# Q12: external mount-path setting does not match the workload.
cat > "$COURSE_DIR/q12/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q12-postgres
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  hostPath:
    path: /tmp/storage-q12
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: storage-q12
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: storage-q12
data:
  data-path: /var/lib/postgresql/wrong
---
apiVersion: v1
kind: Pod
metadata:
  name: postgres
  namespace: storage-q12
spec:
  initContainers:
    - name: verify-storage
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          configured="$(cat /config/data-path)"
          test "$configured" = /var/lib/postgresql/data
      volumeMounts:
        - {name: config, mountPath: /config}
        - {name: data, mountPath: /var/lib/postgresql/data}
  containers:
    - name: database
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts: [{name: data, mountPath: /var/lib/postgresql/data}]
  volumes:
    - name: config
      configMap: {name: postgres-config}
    - name: data
      persistentVolumeClaim: {claimName: postgres-data}
YAML

# Q13: PV node affinity points to a non-existent node.
cat > "$COURSE_DIR/q13/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q13-local
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  local:
    path: /tmp
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values: [retired-worker]
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-data
  namespace: storage-q13
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: local-reader
  namespace: storage-q13
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo q13 >/data/storage-q13-check; sleep 3600"]
      volumeMounts: [{name: data, mountPath: /data}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: local-data}
YAML
# Q14: node placeholders are rendered by create-resources.sh.
cat > "$COURSE_DIR/q14/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q14-local
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  local:
    path: /tmp
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values: [__PV_NODE__]
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pinned-data
  namespace: storage-q14
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: pinned-writer
  namespace: storage-q14
spec:
  nodeSelector:
    kubernetes.io/hostname: __POD_NODE__
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo q14 >/data/storage-q14-check; sleep 3600"]
      volumeMounts: [{name: data, mountPath: /data}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: pinned-data}
YAML

# Q15: StatefulSet template requests a class with no provisioner.
cat > "$COURSE_DIR/q15/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q15-queue
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  hostPath:
    path: /tmp/storage-q15
    type: DirectoryOrCreate
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: queue
  namespace: storage-q15
spec:
  serviceName: queue
  replicas: 1
  selector:
    matchLabels: {app: queue}
  template:
    metadata:
      labels: {app: queue}
    spec:
      containers:
        - name: queue
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
          volumeMounts: [{name: data, mountPath: /data}]
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: [ReadWriteOnce]
        storageClassName: storage-q15-missing
        resources:
          requests: {storage: 1Gi}
YAML

# Q16: create a retained Released PV, then a replacement claim.
cat > "$COURSE_DIR/q16/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q16-recovery
  labels:
    recovery.cnpe.io/id: orders
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/storage-q16
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: old-data
  namespace: storage-q16
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  selector:
    matchLabels:
      recovery.cnpe.io/id: orders
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: seed
  namespace: storage-q16
spec:
  restartPolicy: Never
  containers:
    - name: seed
      image: busybox:1.36
      command: ["sh", "-c", "echo retained-data >/data/marker; sync"]
      volumeMounts: [{name: data, mountPath: /data}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: old-data}
YAML
cat > "$COURSE_DIR/q16/recovery.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: recovered-data
  namespace: storage-q16
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  selector:
    matchLabels:
      recovery.cnpe.io/id: orders
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: recovery
  namespace: storage-q16
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "cat /data/marker; sleep 3600"]
      volumeMounts: [{name: data, mountPath: /data}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: recovered-data}
YAML

# Q17: Block PV cannot satisfy a Filesystem PVC.
cat > "$COURSE_DIR/q17/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q17-block
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  volumeMode: Block
  storageClassName: ""
  hostPath:
    path: /tmp/storage-q17-block
    type: FileOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: filesystem-data
  namespace: storage-q17
spec:
  accessModes: [ReadWriteOnce]
  volumeMode: Filesystem
  storageClassName: ""
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: filesystem-reader
  namespace: storage-q17
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts: [{name: data, mountPath: /data}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: filesystem-data}
YAML

# Q18: subPath does not exist inside the bound volume.
cat > "$COURSE_DIR/q18/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q18-subpath
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  hostPath:
    path: /tmp/storage-q18
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: config-data
  namespace: storage-q18
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: subpath-reader
  namespace: storage-q18
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "cat /etc/app/config.yaml; sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /etc/app/config.yaml
          subPath: config.yaml
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: config-data}
YAML

# Q19: init creates a root-only directory, app remains non-root.
cat > "$COURSE_DIR/q19/incident.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q19-permissions
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  hostPath:
    path: /tmp/storage-q19
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nonroot-data
  namespace: storage-q19
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: Pod
metadata:
  name: nonroot-writer
  namespace: storage-q19
spec:
  initContainers:
    - name: prepare
      image: busybox:1.36
      command: ["sh", "-c", "mkdir -p /data/app; chown 0:0 /data/app; chmod 0700 /data/app"]
      volumeMounts: [{name: data, mountPath: /data}]
  containers:
    - name: app
      image: busybox:1.36
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
      command: ["sh", "-c", "echo ready >/data/app/status; sleep 3600"]
      volumeMounts: [{name: data, mountPath: /data}]
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: nonroot-data}
YAML

# Q20: class mismatch plus missing ConfigMap key.
cat > "$COURSE_DIR/q20/incident.yaml" <<'YAML'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-q20-orders
provisioner: kubernetes.io/no-provisioner
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: storage-q20-orders
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  storageClassName: storage-q20-orders
  hostPath:
    path: /tmp/storage-q20
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: orders-data
  namespace: storage-q20
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: storage-q20-order
  resources:
    requests: {storage: 1Gi}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: orders-config
  namespace: storage-q20
data:
  settings.yaml: |
    mode: production
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders
  namespace: storage-q20
spec:
  replicas: 1
  selector:
    matchLabels: {app: orders}
  template:
    metadata:
      labels: {app: orders}
    spec:
      containers:
        - name: orders
          image: busybox:1.36
          command: ["sh", "-c", "test -s /config/application.yaml; echo ready >/data/status; sleep 3600"]
          volumeMounts:
            - {name: data, mountPath: /data}
            - {name: config, mountPath: /config}
      volumes:
        - name: data
          persistentVolumeClaim: {claimName: orders-data}
        - name: config
          configMap:
            name: orders-config
            items:
              - {key: application.yaml, path: application.yaml}
YAML

for number in $(seq -w 1 20); do
  directory="$COURSE_DIR/q$number"
  cat > "$directory/create-resources.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
kubectl apply -f namespace.yaml
kubectl apply -f incident.yaml
SCRIPT
  cat > "$directory/remove-resources.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
kubectl delete -f incident.yaml --ignore-not-found --wait=true
kubectl delete -f namespace.yaml --ignore-not-found --wait=true
SCRIPT
  chmod +x "$directory/create-resources.sh" "$directory/remove-resources.sh"
done

cat > "$COURSE_DIR/q13/create-resources.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
kubectl get nodes -o jsonpath='{.items[0].metadata.name}{"\n"}' > available-node.txt
kubectl apply -f namespace.yaml
kubectl apply -f incident.yaml
SCRIPT

cat > "$COURSE_DIR/q14/create-resources.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
mapfile -t nodes < <(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
[ "${#nodes[@]}" -ge 2 ] || { echo "Q14 requires at least two nodes" >&2; exit 1; }
sed -e "s/__PV_NODE__/${nodes[0]}/g" -e "s/__POD_NODE__/${nodes[1]}/g" \
  incident.yaml > incident-rendered.yaml
printf '%s\n' "${nodes[1]}" > target-node.txt
kubectl apply -f namespace.yaml
kubectl apply -f incident-rendered.yaml
SCRIPT
cat > "$COURSE_DIR/q14/remove-resources.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
kubectl delete -f incident-rendered.yaml --ignore-not-found --wait=true 2>/dev/null || true
kubectl delete -f namespace.yaml --ignore-not-found --wait=true
rm -f incident-rendered.yaml target-node.txt
SCRIPT

cat > "$COURSE_DIR/q16/create-resources.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
kubectl apply -f namespace.yaml
kubectl apply -f incident.yaml
kubectl -n storage-q16 wait pvc/old-data --for=jsonpath='{.status.phase}'=Bound --timeout=60s
kubectl -n storage-q16 wait pod/seed --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s
kubectl -n storage-q16 delete pod seed --wait=true
kubectl -n storage-q16 delete pvc old-data --wait=true
kubectl apply -f recovery.yaml
SCRIPT
chmod +x "$COURSE_DIR"/q{13,14,16}/{create-resources.sh,remove-resources.sh}

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
cp "$SCRIPT_DIR/README.md" "$COURSE_DIR/README.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md" q-prefixed
touch "$COURSE_DIR/.initialized"

info "Storage troubleshooting lab ready: $COURSE_DIR"
info "Twenty self-contained questions are available in directories q01 through q20"
info "No cluster resources were created by this generator"
