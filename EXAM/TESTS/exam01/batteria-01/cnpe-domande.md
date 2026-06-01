# 📋 CNPE Simulator — Domande
> **Killer Shell** | Kubernetes 1.35 | CNPE Exam Simulator

---

> Git remoto (Gitea): per gli esercizi Git usare i repository remoti, clonandoli nei path attesi.

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"

mkdir -p /course/1 /course/3 /course/10
rm -rf /course/1/team-monitoring /course/3/web-client /course/10/pipelines-repo
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-b01-team-monitoring.git" /course/1/team-monitoring
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-b01-web-client.git" /course/3/web-client
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-b01-pipelines-repo.git" /course/10/pipelines-repo
```

## Indice delle Domande

| Q 1 | Operator Pattern, CRD, Kustomize, Git |
| Q 2 | Prometheus Monitoring |
| Q 3 | Argo CD |
| Q 4 | Flagger for Blue/Green Deployments |
| Q 5 | OPA Gatekeeper, Helm |
| Q 6 | OpenTofu, Terraform |
| Q 7 | OpenCost, Prometheus |
| Q 8 | Grafana, Loki, Logging, Monitoring |
| Q 9 | Kustomize, Prometheus CRDs |
| Q10 | ResourceQuota, Git |
| Q11 | Argo Workflows |
| Q12 | Tekton |
| Q13 | Pod Security Standards |
| Q14 | Jaeger |
| Q15 | Vertical Pod Autoscaler (VPA) |
| Q16 | Argo Rollouts, Canary |
| Q17 | FluxCD |
| Q18 | Kyverno |
| Q19 | Crossplane |
| Q20 | Linkerd, Gateway API |

---

## Question 1 | Operator Pattern, CRD, Kustomize, Git

> 🖥️ **Instance:** `ssh cnpe7683`

A custom operator is in development. The TeamMonitoring CRD has been installed in the cluster from /course/1/team-monitoring ,
which is a local Git repository with Kustomize configuration.

     1. Create a new version v1alpha2 of the CRD, where property target is an object with two string properties: namespace and
        service

     2. Deploy the updated CRD to the cluster using Kustomize

     3. Commit your change to Git in local branch main

     4. Create a TeamMonitoring resource in Namespace pacific , named general . Field target.namespace should be test-ns
        and target.service should be test-svc

---

## Question 2 | Prometheus Monitoring

> 🖥️ **Instance:** `ssh cnpe4328`

Your team is evaluating a minimal Prometheus installation as a potential platform service offering. Prometheus is installed in Namespace
prometheus and can be accessed at http://cnpe4328:30020 .

Currently only Pods in Namespace kariba with the labels app=frontend and app=backend are being scraped.

    1. Extend the existing scrape configuration minimal in the ConfigMap prometheus-server so that Pods with the label app=proxy
       are also scraped. Make sure Prometheus uses the updated configuration

    2. Afterwards, run a query to calculate the sum of http_requests_per_minute{} for each Deployment. Identify the one with the
       highest sum and scale it to 2 replicas




    ℹ️ After restarting Prometheus, it may take 10-20 seconds for newly scraped metrics to become available in query results

---

## Question 3 | Argo CD

> 🖥️ **Instance:** `ssh cnpe3849`

Argo CD is installed with the web interface reachable at http://cnpe3849:30030 and the argocd command installed. Use user
admin with password admin where needed.

    1. The existing Argo CD application web-client is connected to the Git repository cloned at /course/3/web-client . Commit,
      push and sync these changes:

             The Pod label version should be v2

             The content the Nginx server returns should be Lagoon Web Client v2

    2. In /course/3/web-client create new Git branch testing :

             Set the Pod label version should be v3

             The content the Nginx server returns should be Lagoon Web Client v3

             Push the change

    3. Create new Argo CD application web-client-testing . It should have the same settings from web-client with two differences:

             The Git branch to use as source should be testing

             The destination K8s Namespace should be lagoon-testing

      Ensure the new Argo CD application is applied without errors.

---

## Question 4 | Flagger for Blue/Green Deployments

> 🖥️ **Instance:** `ssh cnpe0720`

Flagger is used for two apps In Namespace malawi . It's configured to perform automated Blue/Green deployments without any service
mesh or metrics provider installed.

You can reach app1 at http://cnpe0720:30041 and app2 at http://cnpe0720:30042 .

    1. For Deployment app1 :

              Increase the patch number of the semantic version in env variable APP_VERSION by 1

              Write the events triggered on the Canary resource into /course/4/app1.log

    2. For Deployment app2 change the Canary resource analysis:

           1. Add a basic pre-rollout webhook

           2. It should check if the new Pods respond via HTTP

           3. It should use the canary Service for this check

           4. You can use the template below

       Once done, trigger a new rollout by setting the APP_VERSION to 1.0.1




 analysis:
   interval: 5s
   iterations: 2
   metrics: []
   webhooks:
     - name: "basic-http-test"
       type: pre-rollout
       url: http://TODO # DNS to canary service
       timeout: 5s
       metadata:
         type: "http"
         method: "GET"
         expectedStatus: "200"

---

## Question 5 | OPA Gatekeeper, Helm

> 🖥️ **Instance:** `ssh cnpe7683`

OPA (Open Policy Agent) Gatekeeper is installed and should be used to validate applications in Namespace planet-apps .

    1. In /course/5/infra-opa , complete and create the ConstraintTemplate:

              Pods must include label planet with any value

              Deployments must define at least 2 replicas

              Replace the TODO placeholders in the violation messages with appropriate text

    2. In the same directory, update the PlanetAppConstraint so that it applies only to the planet-apps Namespace, then create it

    3. For Helm chart in /course/5/app-saturn :

              Update the Deployment manifest to meet the minimal OPA requirements without using Helm values

              Set the chart version to 1.0.2

              Deploy the chart as app-saturn in Namespace planet-apps

---

## Question 6 | OpenTofu, Terraform

> 🖥️ **Instance:** `ssh cnpe4328`

Your platform team uses OpenTofu/Terraform to manage Kubernetes resources.

Perform the following, command tofu ready to be used:

    1. For /course/6/service-black-bean create a human-readable diff output of the changes that would be applied and store it at
         /course/6/service-black-bean/diff.txt

    2. For /course/6/service-green-curry raise the replicas for the deployment resource green-curry to 2 and apply the change

    3. Update /course/6/service-red-velvet/main.tf :

               Add a new NodePort Service named cake , nodePort 30060

               The OpenTofu/Terraform resource name should also be named cake

               It should point to the existing Deployment red-velvet

---

## Question 7 | OpenCost, Prometheus

> 🖥️ **Instance:** `ssh cnpe1080`

OpenCost is installed with web interface at http://cnpe1080:30070 and kubectl cost configured. OpenCost uses Prometheus for
data and storage, reachable at http://cnpe1080:30077 :

    1. Update the OpenCost custom pricing model in Namespace opencost :

              Set internetNetworkEgress to 0.25

              Set spotCPU to 0.015

      Ensure OpenCost is working with the updated values.

    2. Run Prometheus query kube_pod_info{...} filtered by Namespace atlantic and write the result into
       /course/7/result.txt

    3. Find Prometheus targets with scraping errors and write their error message into /course/7/error.txt




    ℹ️ To extract information from the Prometheus UI, simply highlight the text in Firefox, copy it, and paste it into the file



    ℹ️ To use kubectl cost with OpenCost the --opencost argument might be needed

---

## Question 8 | Grafana, Loki, Logging, Monitoring

> 🖥️ **Instance:** `ssh cnpe0720`

Grafana can be accessed at http://cnpe0720:30080 and Loki is configured as the only datasource.

    1. Set "Maximum lines" for the Loki datasource to 100

    2. In the logging dashboard, update the existing panel's query to the following and save the dashboard:


          count(rate({pod=~"connection.*"}[5m]))


       Use the query exactly as shown, without additional spacing or reordering

    3. Two Pods are producing error logs. Run the Loki query below to locate them, then scale their respective controllers down to 0 :


          {job=~"loki.*"} |= "ERROR"

---

## Question 9 | Kustomize, Prometheus CRDs

> 🖥️ **Instance:** `ssh cnpe2561`

A tightly customized Prometheus Operator configuration is managed via Kustomize with a staging and a production overlay at
/course/9/prom-config . The configuration has been applied like this:


  kubectl apply -k /course/9/prom-config/overlays/staging
  kubectl apply -k /course/9/prom-config/overlays/production


Perform the following in the Kustomize configuration and apply all changes:

      1. ConfigMap operator-config should have:

               reconcile_interval_seconds: "30" in staging

               reconcile_interval_seconds: "10" in production

      2. PodMonitor proxy-monitor should have:

               attachMetadata: { node: true } in base (inherited by both overlays)

               sampleLimit: 6000 in staging

               sampleLimit: 7000 in production

      3. Add the crd-prometheusrules.yaml to base configuration so it will be installed in all environments

---

## Question 10 | ResourceQuota, Git

> 🖥️ **Instance:** `ssh cnpe1080`

Using ResourceQuotas, limit storage usage in Namespaces caspian-pipeline1 , caspian-pipeline2 and caspian-pipeline3 .

One of these Namespaces recently requested 100Gi storage, but the change was reverted again. Check commits in the Git repository
/course/10/pipelines-repo to identify it. Apply the following rules:

    1. For the identified Namespace (which previously requested the 100Gi storage):

             Prevent creation of any PVCs

             Also delete any existing PVCs, scale down Pods if necessary

    2. The other two Namespaces should each be limited to:

             Creating a maximum of 2 PVCs

             Requesting a total of 100Mi storage across all PVCs




    ℹ️ You can perform the changes directly in /course/10/pipelines-repo , but it is not required for the solution

---

## Question 11 | Argo Workflows

> 🖥️ **Instance:** `ssh cnpe3849`

Your platform team wants to provide some example Argo WorkflowTemplates to ease adoption for new users. Argo Workflows has been
installed with argo CLI and UI at http://cnpe3849:30110 .

    1. The existing Workflow of WorkflowTemplate greeter failed:

              Fix the error in the WorkflowTemplate

              Submit a new Workflow which succeeds

    2. There is WorkflowTemplate /course/11/configurator.yaml which creates ConfigMaps in a passed Namespace:

              Create step create-config2 by copying create-config1 , it should create ConfigMap cm2

              Run the new step in parallel to the existing one

              Apply the updated WorkflowTemplate

              Submit a new Workflow for Namespace kaw which succeeds

Delete failed Workflow(s) and keep only one successful one per WorkflowTemplate.

---

## Question 12| Tekton

> 🖥️ **Instance:** `ssh cnpe2561`

Your platform team uses Tekton to automate various team tasks. Tekton Pipelines has been installed, with tkn CLI, kubectl tkn
plugin and the Tekton Dashboard at http://cnpe2561:30120 .

All Tekton Pipelines etc should run in Namespace builder . The code for two pipelines is available at /course/12 .

    1. Add new Task p1-create-labels to the Pipeline p1-team-onboarding :

             It should add label auto-created: true to the Namespace that was created in p1-create-namespace

             It should run in parallel with Task p1-create-roles

             Run the updated Pipeline for team name butter

             Run the updated Pipeline for team name croissant

    2. Apply all resources from /course/12/p2-team-scanner :

             Run the Pipeline p2-team-scanner with:

                    team-name: bread

                    forbidden1: miner

                    forbidden2: torrent

             Write the PipelineRun logs into /course/12/p2.log
If a Pipeline you run fails, delete the failed PipelineRun for cleanup.

---

## Question 13| Pod Security Standards

> 🖥️ **Instance:** `ssh cnpe0720`

The Namespace ammersee-legacy currently has no Pod Security Standards applied. The manifests for existing workloads are available
at /course/13 . You're tasked with:

    1. Configure the Namespace to enforce the restricted Pod Security Standard

    2. Identify and fix any non-compliant workloads so they can be restarted

---

## Question 14 | Jaeger

> 🖥️ **Instance:** `ssh cnpe7683`

Namespace eyre contains a Jaeger instance with UI at http://cnpe7683:30014 and multiple services which generate distributed
traces. Using Jaeger:

    1. Find the service with tag ai.model=fast_v1.2 and update its Deployment to use thinking_v1.6 instead

    2. Find the service with tag access.public=true and scale its Deployment to 2 replicas

    3. Export exactly 10 traces from service speechai in JSON format to /course/14/traces.json on cnpe7683

---

## Question 15 | Vertical Pod Autoscaler (VPA)

> 🖥️ **Instance:** `ssh cnpe1080`

A single etcd instance is running in Namespace sargasso and you should create a VerticalPodAutoscaler (VPA) resource for it.

Add VPA named etcd-vpa to file /course/15/etcd.yaml and create it. Don't make any changes to the StatefulSet in that file.

    1. The VPA should only apply recommendations at Pod creation:

               Minimum cpu: 20m , memory: 20Mi

               Maximum cpu: 50m , memory: 50Mi

    2. Restart the Pod so that the VPA recommendations are applied

---

## Question 16 | Argo Rollouts, Canary

> 🖥️ **Instance:** `ssh cnpe2561`

Argo Rollouts is installed with dashboard at http://cnpe2561:30160 .

In Namespace baltic , a Rollout webapp is currently paused during a canary deployment at 50% traffic.

    1. Promote the Rollout to complete all remaining steps

    2. Replace the pause step with an analysis step

              Use template at /course/16/analysis_template.yaml
               Complete the template URL to check the webapp-canary Service

      3. Trigger a new rollout by setting environment variable VERSION to 1.18.4




      ℹ️ The webapp can be reached at http://cnpe2561:30161 and its Pods respond with their version

---

## Question 17 | FluxCD

> 🖥️ **Instance:** `ssh cnpe7683`

FluxCD is installed and the flux CLI is available.

    1. Resume the Kustomization havel-west to correct the drift of repository /course/17/havel-west

    2. Deploy /course/17/havel-east :

               Create GitRepository havel-east pointing to http://192.168.100.21:3000/projects/havel-east.git branch main

               Create Kustomization havel-east deploying from GitRepository havel-east to Namespace havel-east

---

## Question 18 | Kyverno

> 🖥️ **Instance:** `ssh cnpe4328`

Kyverno is installed and should be used to mutate resources in Namespace caribbean . The Kyverno CLI is available via kyverno .

    1. Create a NamespacedMutatingPolicy named security-check which:

             Mutates Pods during CREATE and UPDATE

             Adds the label audit: pending to the Pods, but only if the label does not already exist

    2. Create two Pods named test-pending and test-passed with image nginx:1-alpine

    3. Update the label on test-passed to audit: passed , Kyverno should not change it back
It's planned for the future that another service checks for Pods with label audit: pending , performs security checks, and updates the
label value.

---

## Question 19 | Crossplane

> 🖥️ **Instance:** `ssh cnpe3849`

Crossplane is installed. The platform team has created a CompositeResourceDefinition redis.cache.killer.sh and a partial
Composition that uses native Kubernetes resources.

    1. Create a Redis resource cache in Namespace danau with size medium

    2. Extend the Composition in /course/19/composition.yaml to also create a Service:

              Named redis

              Mapping port 6379 to the Pods of the StatefulSet

              Type ClusterIP

              Follow the existing pattern for patches and readinessChecks

    3. Verify the Service was added to the existing Redis resources

---

## Question 20 | Linkerd, Gateway API

> 🖥️ **Instance:** `ssh cnpe4328`

Namespace saltlake-app is part of the Linkerd mesh:

      1. Create two Server resources:

                  frontend for Pod label app: frontend on port 80

                  backend for Pod label app: backend on port 80

      2. Fix existing AuthorizationPolicy frontend-to-backend to allow the frontend Pods to access the backend Pods

      3. There are two backend versions available via Services backend-v1 and backend-v2 . Create an HTTPRoute (Gateway API)
         backend-canary for the backend Service that implements traffic splitting:
              10% to backend-v1

              90% to backend-v2




    ℹ️ Test connection for example with kubectl -n saltlake-app exec deploy/frontend -c frontend -- curl backend

---
