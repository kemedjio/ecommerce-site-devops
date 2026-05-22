                                      Online boutique App project

This is a type of e-commerce platform, but unlike Amazon-type stores, it focuses on:

- **Niche or curated products**
- **Unique / limited collections**
- **Strong brand identity & style**

Think of it as a **digital version of a small, stylish fashion store**.

But from a **technical perspective**, modern boutique apps are **not built as a single application**.

They are built using **Microservices Architecture**.
>
>This online boutique app is made up of multiple services like:
>
>### 🧾 Product Catalog Service
>
>- Manages product list, categories, pricing
>
>### 🛒 Cart Service
>
>- Handles user cart (add/remove items)
>
>### 💳 Payment Service
>
>- Processes payments (UPI, cards)
>
>### 📦 Order Service
>
>- Manages order lifecycle
>
>### 👤 Frontend Service
>
>- Authentication & profiles
>
>### 🚚 Shipping Service
>
>- Delivery tracking & logistics
>
>### Etc..
>
>---
>
># How These Services Communicate
>
>- REST APIs (HTTP)
>- gRPC (faster internal communication)
>- Message queues (Kafka / RabbitMQ)
>
>👉 Example:
>
>- Cart service → calls Product service
>- Order service → calls Payment service
>
>---

# **Architecture**

**Online Boutique** is composed of 11 microservices written in different languages that talk to each other over gRPC.

![image.png](docs/images/Ar

Screenshots:

![image.png](docs/images/Screenshot01.png)

---

**Most services are stateless**, and **only the cart uses persistence (Redis)**. Let’s break it down cleanly.

# How data works in `microservices-demo`

This project is **designed** to:

- Demonstrate **microservice communication**
- Be **easy to deploy anywhere**
- Avoid complex database ops

So it uses **minimal persistence** on purpose.

---

## Service-by-Service Data Breakdown

### ✅ **cartservice** → ✔️ HAS persistence

**Storage used:**

- **Redis**

**What’s stored:**

- User cart items
- Quantity, product ID
📌 In Kubernetes:

- Redis runs as a pod (or StatefulSet)
- Cart data is lost if Redis is deleted (by default)

---

### ❌ **orders / checkout** → NO real database

There is **NO dedicated “orders database”**.

**checkoutservice:**

- Aggregates data from:
    - cartservice
    - paymentservice
    - shippingservice
    - emailservice
- Simulates order placement
- Does **not persist orders**

---

### ❌ **productcatalogservice**

**Storage:**

- Static JSON file
- Loaded into memory at startup

**No DB**

- Products reset on restart

---

### ❌ **recommendationservice**

**Storage:**

- Stateless
- Generates recommendations dynamically

---

### ❌ **paymentservice**

**Storage:**

- None
- Fake payment processor

---

### ❌ **shippingservice**

**Storage:**

- None
- Simulated shipping cost logic

---

### ❌ **emailservice**

**Storage:**

- None
- Just logs “email sent”

---

### ❌ **adservice**

**Storage:**

- In-memory ad data
- No persistence

---

### ❌ **frontend**

**Storage:**

- Stateless
- Just UI + API calls

---

### ❌ **currencyservice?**

> “The project focus on platform concerns like CI/CD, observability, scaling, and networking.”

---

# Project Architecture
# Implementation

## Install tools in Local Machine

- AWS CLI
- Terraform in your local machine
- Create an IAM user and create access key and secret access key for the user and do `aws configure`

## Terraform Run to create the infrastructure

Clone te repo , `cd` to `terraform` directory. 

```bash
terraform init
Terraform plan 
terraform apply
```

## Set up Terraform Remote Backend (Optional)

Create a bucket using Console or AWS CLI.

```bash
aws s3api create-bucket \
  --bucket ecommerce-terraform-backend-bucket \
  --region us-east-1
```

Enable versioning and bucket encryption:

```bash
# Enable versioning

Add this below backend block in `terraform.tf` file

```bash
terraform {
  backend "s3" {
    bucket = "ecommerce-terraform-backend-bucket"
    key    = "s3-backend"
    region = "us-east-1"
  }
}
```

## Bastion Host Configuration

SSH to bastion and  install the below tools:

- AWS CLI
- kubectl client
- HELM
- eksctl

# update the kube config file and check
aws eks update-kubeconfig --region <your-region> --name <your-cluster-name> 

kubectl get nodes

# Install the AWS load balancer controller

Create an IAM OIDC provider. 

```
eksctl utils associate-iam-oidc-provider \
    --region us-east-1 \
    --cluster ecommerce-cluster \
    --approve
```

**Create IAM role using `eksctl`.**

1. Download an IAM policy for the AWS Load Balancer Controller 
    ```bash
    curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json
    ```
    
2. Create an IAM policy using the policy downloaded in the previous step.
    
    ```bash
    aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file://iam_policy.json
    ```
    
3. Replace the values for cluster name, region code, and account ID.
    
    ```bash
    eksctl create iamserviceaccount \
        --cluster=ecommerce-cluster \
        --namespace=kube-system \
        --name=aws-load-balancer-controller \
        --attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
        --override-existing-serviceaccounts \
        --region us-east-1 \
        --approve
    ```
    

**Install AWS Load Balancer Controller**

1. Add the `eks-charts` Helm chart repository. 
    ```bash
    helm repo add eks https://aws.github.io/eks-charts
    ```
    

        helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
          -n kube-system \
          --set clusterName=ecommerce-cluster \
          --set region=us-east-1 \
          --set vpcId=vpc-043ed20a9ec883107 \
          --set serviceAccount.create=false \
          --set serviceAccount.name=aws-load-balancer-controller \
          --set controllerConfig.featureGates.NLBGatewayAPI=true \
          --set controllerConfig.featureGates.ALBGatewayAPI=true \
          --version 3.0.0
        ```
        

**Verify that the controller is installed**

    
    ```bash
    kubectl get deployment -n kube-system aws-load-balancer-controller
    ```
    
## Gateway API

Installation of Gateway API CRDs

- Standard Gateway API CRDs:  [REQUIRED]
    
    ```bash
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml
    ```
    
- Experimental Gateway API CRDs:  [OPTIONAL: Used for L4 Routes]
    
    ```bash
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml
    ```
    
- Installation of LBC Gateway API specific CRDs:
    
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml
    ```
    

Create a gateway class:

`gateway-class.yaml`

```bash
# alb-gatewayclass.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: aws-alb-gateway-class
spec:
  controllerName: gateway.k8s.aws/alb
```

apply the manifest:

```bash
kubectl apply -f gateway-class.yaml
```

Create the Load balancer configuration:

This is required for AWS LBC controller and might not be required for othe rgateway api controller.

`alb-config.yaml`

```bash
# lbconfig.yaml
apiVersion: gateway.k8s.aws/v1beta1
kind: LoadBalancerConfiguration
metadata:
  name: app-gw-lbconfig
  namespace: default
spec:
  scheme: internet-facing
  listenerConfigurations:
    - protocolPort: HTTPS:443
      defaultCertificate: <certificate arn>
```

Apply :

```bash
kubectl apply -f alb-config.yaml
```

**Create the gateway:**

`gateway.yaml`

```bash
# my-alb-gateway.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: app-alb-gateway
  namespace: default
spec:
  gatewayClassName: aws-alb-gateway-class
  infrastructure:
    parametersRef:
      kind: LoadBalancerConfiguration
      name: app-gw-lbconfig
      group: gateway.k8s.aws
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "*.devopsdock.site"
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    protocol: HTTPS
    hostname: "*.devopsdock.site"
    port: 443
    allowedRoutes:
      namespaces:
        from: All
```

Apply Gateway manifests:

```bash
kubectl apply -f gateway.yaml
```

Verify the gateway and the load balancer in the AWS UI.

```bash
kubectl get gateway
```

## **Deploying External DNS:**

Create a file with below content for IAM policy:

vi `policy.json`

```bash
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets",
        "route53:ListTagsForResources"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
```

Create policy from the policy document

```bash
aws iam create-policy --policy-name "AllowExternalDNSUpdates" --policy-document file://policy.json

export POLICY_ARN=$(aws iam list-policies \
 --query 'Policies[?PolicyName==`AllowExternalDNSUpdates`].Arn' --output text)
 
export EKS_CLUSTER_NAME=ecommerce-cluster
```

## **We will use pod identity agent for the external dns setup:**

We have created this addon while creating the cluster, so igonre this step.

**Check Pod Identity Agent is enabled**

```
eksctl create addon --cluster $EKS_CLUSTER_NAME --name eks-pod-identity-agent
```

**Create an IAM role bound to a service account**

**Use eksctl with eksctl created EKS cluster**

Create a namespace:

```bash
kubectl create ns external-dns
```

```bash
eksctl create podidentityassociation \
  --cluster $EKS_CLUSTER_NAME \
  --namespace external-dns \
  --service-account-name external-dns \
  --role-name external-dns-pod-identity-role \
  --permission-policy-arns $POLICY_ARN
```

**Deploy ExternalDNS using Pod Identity**

Unlike the IRSA method, Pod Identity requires no further steps, nor service account annotations, since the pod identity association will bind the service account to the given IAM role, hence to a policy holding the requested set of permissions. The EKS Pod Identity Agent handles credential injection at runtime.

Add the Repo:

```bash
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
```

Deploy in a separte Namespace:

```bash
helm install external-dns external-dns/external-dns -n external-dns --version 1.20.0
```
Verify:

```bash
kubectl get pod -n external-dns
```
Get the values file:

```bash
helm show values external-dns/external-dns --version 1.20.0 > external-dns-values-1.20.0.yaml
```

Upgrade the install:

```bash
helm upgrade -i external-dns external-dns/external-dns -f external-dns-values-1.20.0.yaml -n external-dns --version 1.20.0
```

## Deploy ArgoCD

Docs: [https://artifacthub.io/packages/helm/argo/argo-cd](https://artifacthub.io/packages/helm/argo/argo-cd) 

**Add ArgoCD repo**

```bash
helm repo add argo https://argoproj.github.io/argo-helm
```

Get the values:

```bash
helm show values argo/argo-cd --version 9.4.0 > argocd-values-9.4.0.yaml
```

Modify the values file:

Add  ”`server.insecure: true`”  line explicitly :

Add this `kustomize.buildOptions: "--enable-helm` line in the `config` section as Kustomize is require to combine the helm values and manifest file.

- Helm support inside Kustomize is considered an **unsafe plugin**, so it is disabled.
- You must explicitly allow it.

    kustomize.buildOptions: "--enable-helm"


Install the chart:

```bash
helm install argo-cd argo/argo-cd -n argocd -f argocd-values-9.4.0.yaml --version 9.4.0 --create-namespace
```

Add Target group config:

`target-grp-config.yaml`

```bash
apiVersion: gateway.k8s.aws/v1beta1
kind: TargetGroupConfiguration
metadata:
  name: argo-tg-config
  namespace: argocd
spec:
  targetReference:
    name: argo-cd-argocd-server
  defaultConfiguration:
    targetType: ip
```

Apply:

```bash
kubectl apply -f target-grp-config.yaml 
```

Access ArgoCd user interface get the password and user:

```bash
#get auto generated password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```


##  set up the CI part in Github Action.

```bash
mkdir -p .github/workflows
```
Inside the `workflows` create two config file.

**`microservice-ci.yaml`**

```bash
name: Microservice CI

on:
  workflow_call:
    inputs:
      service:
        required: true
        type: string

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/microservices-demo/${{ inputs.service }}:sha-${{ github.sha }}

    steps:
      # -------------------
      # Checkout source
      # -------------------
      - name: Checkout code
        uses: actions/checkout@v4

      # -------------------
      # Docker Buildx (cache support)
      # -------------------
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      # -------------------
      # Login to GHCR
      # -------------------
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # -------------------
      # Build Docker image (cached)
      # -------------------
      - name: Build Image
        run: |
          docker build \
            --cache-from=type=gha \
            --cache-to=type=gha,mode=max \
            -t $IMAGE_NAME \
            ./src/${{ inputs.service }}

      # -------------------
      # Security Scan (before push)
      # -------------------
      - name: Run Trivy Scan
        uses: aquasecurity/trivy-action@0.20.0
        with:
          scan-type: image
          image-ref: ${{ env.IMAGE_NAME }}
          severity: HIGH,CRITICAL
          exit-code: 1
          vuln-type: os,library

      # -------------------
      # Push image (only if scan passes)
      # -------------------
      - name: Push Image
        run: |
          docker push $IMAGE_NAME
```

**`ci-trigger.yaml`**

```bash
name: Microservices Trigger CI

on:
  push:
    branches: [ main ]
    paths:
      - "src/**"

permissions:
  contents: read
  packages: write

jobs:
  # -------------------------------
  # Job 1: Detect changed services
  # -------------------------------
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      services: ${{ steps.changed.outputs.services }}

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect changed services
        id: changed
        run: |
          SERVICES=$(git diff --name-only ${{ github.event.before }} ${{ github.sha }} \
            | grep '^src/' \
            | cut -d'/' -f2 \
            | sort -u \
            | jq -R -s -c 'split("\n")[:-1]')

          echo "Detected services: $SERVICES"
          echo "services=$SERVICES" >> $GITHUB_OUTPUT

  # --------------------------------------------------
  # Job 2: Call reusable workflow (matrix per service)
  # --------------------------------------------------
  build-and-push:
    needs: detect-changes
    if: needs.detect-changes.outputs.services != '[]'

    strategy:
      fail-fast: false
      matrix:
        service: ${{ fromJson(needs.detect-changes.outputs.services) }}

    # 🚨 IMPORTANT:
    # Reusable workflows are called at JOB level
    uses: ./.github/workflows/microservice-ci.yaml

    with:
      service: ${{ matrix.service }}
```


#Create the CD part
    
    `microservices-extra-kube-manifests/target-grp.yaml`
    
    ```bash
    #target group configuration
    apiVersion: gateway.k8s.aws/v1beta1
    kind: TargetGroupConfiguration
    metadata:
      name: app-tg-config
      namespace: boutique-app
    spec:
      targetReference:
        name: frontend
      defaultConfiguration:
        targetType: ip
    ```
  
    
- **Create the HTTProute for the app so that it will get attached with the gateway and add as a listener in the load balancer.**
    
    `microservices-extra-kube-manifests/HTTProute.yaml` 
    
    ```bash
    apiVersion: gateway.networking.k8s.io/v1beta1
    kind: HTTPRoute
    metadata:
      name: http-app-route
      namespace: boutique-app
    spec:
      hostnames:
        - "app.devopsdock.site"
      parentRefs:
      - group: gateway.networking.k8s.io
        namespace: default
        kind: Gateway
        name: app-alb-gateway
        sectionName: http
      - group: gateway.networking.k8s.io
        namespace: default
        kind: Gateway
        name: app-alb-gateway
        sectionName: https
      rules:
      - backendRefs:
        - name: frontend
          port: 80
    ```
    
- ArgoCD can deploy **multiple sources from one repo** inside a single Application using `Kustomize`.

Create a kustomize config file

- Do NOT apply this file manually
- You commit this file to Git.
- Then ArgoCD does everything.

**`kustomization.yaml`  (Root Dir)**

```bash
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - microservices-extra-kube-manifests/HTTProute.yaml
  - microservices-extra-kube-manifests/target-grp.yaml

helmCharts:
  - name: boutique-app
    repo: oci://ghcr.io/laxmikantagiri/onlineboutique
    version: 0.10.4
    releaseName: boutique-app
    namespace: boutique-app
    valuesFile: helm-chart/values.yaml
```


## Create our Argocd App

Create the argo app manifest and place it inside the `argocd/argocd-apps` directory fto organise better.

**`boutique-app.yaml`**

```bash
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: boutique-app
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/laxmikantagiri/Production-Grade_GitOps-Driven_Microservices-Demo.git
    targetRevision: HEAD
    path: .

  destination:
    server: https://kubernetes.default.svc
    namespace: boutique-app

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

Now apply the file:

```bash
kubectl apply -f boutique-app.yaml
```

Check the ArgoCD UI you should see the app visible there. And all Synced.

![image.png](docs/images/image%203.png)

# Now Lets integrate the CI with CD

In the current setup the CD (ArgoCD) never takes the updated image form the CI. We need an image updated here.

So whenever CI part is done and the image is pushed to the registry the same image tag should be automatically updated in the helm values file. After that rest ArgoCD can its job.

## Install Argo Image Updater.

**Understand What ArgoCD Image Updater Actually Does**

It watches your container registry and when a new tag appears, it:

- updates the image tag inside Git
- commits the change
- ArgoCD syncs automatically

No kubectl. No manual deploy. Pure GitOps.

Install in the cluster:

Add the repo

```bash
helm repo add argo https://argoproj.github.io/argo-helm
```

Install the chart:

```bash
helm install argocd-image-updater argo/argocd-image-updater -f argo-image-updater-values-1.0.5.yaml -n argocd --version 1.0.5
```

</aside>

In our case the repo is public so its not required.

Install the chart:

```bash
helm install argocd-image-updater argo/argocd-image-updater -n argocd --version 1.0.5
```

Make sure its running:

```bash

Add `imageupdater` Custom Resource

Apply it:

```bash
kubectl apply -f image-updater.yaml
```
Verify
```bash
kubectl get imageupdater -n argocd

NAME                     AGE
boutique-image-updater   13s
```

Access the website `app.devopsdock.site`

It should be accessible.

# Observability

We  dont manage the observability stack by Argocd. Because anyone having access to Argocd can modify it.

## 1. Monitoring

Create a namespace:

```bash
kubectl create ns monitoring
```

## Setup Slack

Create a dedicated channel where you want to receive the alerts.

**`#alertmanager`**

Keep it public.

![image.png](docs/images/image%2010.png)

After this is done 

Give name and choose the workspace and create.


Head to **`Incoming Webhook`**

Turn it ON

Scroll down then Click on **`Add New Webhook`**

Select the channel and then allow.

Copy the Webhook and keep it somewhere pasted.

### Create a Kubernetes Secret for Slack Webhook

On your cluster:

```bash
kubectl create secret generic alertmanager-slack-webhook \
  --from-literal=slack-webhook-url="<Webhook FQDN>" \
  -n monitoring
```

Verify:

```bash
kubectl get secret alertmanager-slack-webhook -n monitoring
```

### Kube-Prometheus-Stack

Add `kube-prometheus-stack`  repo:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

get the helm values and save it in a file:

```bash
helm show values prometheus-community/kube-prometheus-stack --version 81.6.3 > observability/helm-values/kube-prom-stack-81.6.3.yaml 
```

Edit in `vi`

Attach the secret in `alertmanagerSpec:` section. So that it will mount to the pod.

```bash
alertmanager:
  alertmanagerSpec:
        secrets:
            - alertmanager-slack-webhook
```

Go to `alertmanger` section and find its `config` block:

```bash
config:
    global:
      resolve_timeout: 5m
    route:
      group_by: ['namespace']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      receiver: 'slack-notification'
      routes:
      - receiver: 'slack-notification'
        matchers:
          - severity = "critical"
    receivers:
    - name: 'slack-notification'
      slack_configs:
          - api_url_file: /etc/alertmanager/secrets/alertmanager-slack-webhook/slack-webhook-url
           channel: '#alerts'
           send_resolved: true
    templates:
    - '/etc/alertmanager/config/*.tmpl'
```

>### Slack Config
>
>```yaml
>api_url:'https://hooks.slack.com/services/...'channel:'#alerts'send_resolved:true
>```
>
># 5. Templates
>
>```yaml
>templates:-'/etc/alertmanager/config/*.tmpl'
>```

>---
>
># How It Actually Works (End-to-End Flow)
>
>### 1. Application exposes metrics
>
>Example:
>
>```
>http_requests_total
>pod_memory_usage_bytes
>up
>```
>---
>
>### 2. Prometheus scrapes those metrics
>
>From:
>
>- Pods
>- Services
>- Nodes
>- Kubernetes API
>- etc.
>
>---
>
>### 3. Alert Rules Define When Something Is Critical
>
>Inside kube-prometheus-stack, there are many alert rules like:
>
>```yaml
>-alert:PodCrashLoopingexpr:kube_pod_container_status_restarts_total>5for:5mlabels:severity:criticalannotations:description:Podisrestartingfrequently
>```

>
>### 4. Prometheus Sends Alert to Alertmanager
>
>When the condition becomes true:
>
>```json
>{"alertname":"PodCrashLooping","severity":"critical","namespace":"production"}
>```
>
>Prometheus pushes this to Alertmanager.
>
>---
>
>### 5. Alertmanager Routes Based on Labels
>
>Now your config says:
>
>```yaml
>matchers:-severity="critical"
>```
>

Install Prometheus:

```bash
helm upgrade -i kube-prometheus-stack prometheus-community/kube-prometheus-stack --version 81.6.3 -f helm-values/kube-prom-stack-81.6.3.yaml -n monitoring
```

Check if all the pods are running:

```bash
kubectl get po -n monitoring
```

Check the Services:

```bash
kubectl get svc -n monitoring
```

### Now Lets Expose the **`Grafana`** and **`Prometheus`** and access the UI of them

The helm chart doesn’t include the HTTProute and and the targetconfiguration in its template . So we will add them by writing the manifest file and manage externally.

Create a file in the `observability` directory

**`HTTProute-grafana.yaml`**

```bash
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: grafana-route
  namespace: monitoring
spec:
  hostnames:
    - "grafana.devopsdock.site"
  parentRefs:
  - group: gateway.networking.k8s.io
    namespace: default
    kind: Gateway
    name: app-alb-gateway
    sectionName: http
  - group: gateway.networking.k8s.io
    namespace: default
    kind: Gateway
    name: app-alb-gateway
    sectionName: https
  rules:
  - backendRefs:
    - name: kube-prometheus-stack-grafana
      port: 80
```

Use the service name and port in the backend refs.

**`target-grp-grafana.yaml`**

```bash
apiVersion: gateway.k8s.aws/v1beta1
kind: TargetGroupConfiguration
metadata:
  name: grafana-tg-config
  namespace: monitoring
spec:
  targetReference:
    name: kube-prometheus-stack-grafana 
  defaultConfiguration:
    targetType: ip

```

Apply both the files

```bash
kubectl apply -f HTTProute-grafana.yaml
kubectl apply -f target-grp-grafana.yaml
```

Get Grafana 'admin' user password by running:

```bash
kubectl --namespace monitoring get secrets kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

Now similarly lets expose the `Prometheus`:

create another set of httproute and targetgroupconfiguration for preometheus.

**`HTTProute-prometheus.yaml`**

```bash
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: prometheus-route
  namespace: monitoring
spec:
  hostnames:
    - "prometheus.devopsdock.site"
  parentRefs:
  - group: gateway.networking.k8s.io
    namespace: default
    kind: Gateway
    name: app-alb-gateway
    sectionName: http
  - group: gateway.networking.k8s.io
    namespace: default
    kind: Gateway
    name: app-alb-gateway
    sectionName: https
  rules:
  - backendRefs:
    - name: kube-prometheus-stack-prometheus
      port: 9090
```

**`target-grp-prometheus.yaml`**

```bash
apiVersion: gateway.k8s.aws/v1beta1
kind: TargetGroupConfiguration
metadata:
  name: prometheus-tg-config
  namespace: monitoring
spec:
  targetReference:
    name: kube-prometheus-stack-prometheus 
  defaultConfiguration:
    targetType: ip
```

Now apply both the files:

```bash
kubectl apply -f HTTProute-prometheus.yaml
kubectl apply -f target-grp-prometheus.yaml
```

Verify:

```bash
kubectl  get targetgroupconfiguration -n monitoring



## 2. Logging

- we will use elasticsearch for logsstore, filebeat for log shipping and kibana for the visualization.

### Now Lets install the ECK- Components which the operator will manage:


```bash
helm install eck-elasticsearch elastic/eck-elasticsearch --version 0.18.0 -n logging
```

Make sure its running:

```bash
kubectl get po -n logging


You can check the CR as well:

```bash
kubectl get elasticsearch -n logging
```


```
We will use Filebeat:


```bash
helm show values elastic/eck-beats --version 0.18.0 > observability/helm-values/eck-beats-0.18.0.yaml
```

Edit the file:

And add the following

vi **`observability/helm-values/eck-beats-0.18.0.yaml`**

```bash
---

version: 9.3.0

labels: {}

annotations: {}

type: filebeat

elasticsearchRef:
  name: eck-elasticsearch
  namespace: logging

daemonSet:
  podTemplate:
    spec:
      serviceAccount: elastic-beat-filebeat
      automountServiceAccountToken: true
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirstWithHostNet
      hostNetwork: true
      containers:
        - name: filebeat
          securityContext:
            runAsUser: 0
          env:
          - name: NODE_NAME
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
          volumeMounts:
          - mountPath: /var/log/containers
            name: varlogcontainers
          - mountPath: /var/log/pods
            name: varlogpods
          - mountPath: /var/lib/docker/containers
            name: varlibdockercontainers  
      volumes:
        - name: varlogcontainers
          hostPath:
            path: /var/log/containers
            type: Directory
        - name: varlogpods
          hostPath:
            path: /var/log/pods
            type: Directory
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers

config:
  filebeat:
      autodiscover:
        providers:
        - node: ${NODE_NAME}
          type: kubernetes
          hints:
            enabled: true
            default_config:
              type: filestream
              id: kubernetes-container-logs-${data.kubernetes.pod.name}-${data.kubernetes.container.id}
              paths:
              - /var/log/containers/*${data.kubernetes.container.id}.log
              parsers:
              - container: {}
              prospector:
                scanner:
                  fingerprint.enabled: true
                  symlinks: true
              file_identity.fingerprint: {}
  processors:
   - add_cloud_metadata: {}
   - add_host_metadata: {}

secureSettings: []

serviceAccount:
  name: elastic-beat-filebeat
  namespace: logging

clusterRoleBinding:
  name: elastic-beat-autodiscover-binding
  subjects:
  - kind: ServiceAccount
    name: elastic-beat-filebeat
    namespace: logging
  roleRef:
    kind: ClusterRole
    name: elastic-beat-autodiscover
    apiGroup: rbac.authorization.k8s.io

clusterRole:
  name: elastic-beat-autodiscover
  rules:
  - apiGroups: [""]
    resources:
    - events
    - pods
    - namespaces
    - nodes
    verbs:
    - get
    - watch
    - list
  - apiGroups: ["apps"]
    resources:
    - replicasets
    verbs:
    - get
    - list
    - watch
  - apiGroups: ["batch"]
    resources:
    - jobs
    verbs:
    - get
    - list
    - watch
```


Install:

```bash
helm upgrade -i eck-beats elastic/eck-beats --version 0.18.0 -f helm-values/eck-beats-0.18.0.yaml -n logging
```

Run:

```bash
kubectl get po -n logging

```

Check the CR:

```bash
kubectl get beats -n logging
```

Installing **`eck-Kibana`:**

Get the values:

```bash
helm show values elastic/eck-kibana --version 0.18.0 > observability/helm-values/eck-kibana-0.18.0.yaml
```

Edit:

vi **`observability/helm-values/eck-kibana-0.18.0.yaml`**

```bash
elasticsearchRef:
  name: eck-elasticsearch
  namespace: logging

```

Install:

```bash
helm install eck-kibana elastic/eck-kibana --version 0.18.0 -f observability/helm-values/eck-kibana-0.18.0.yaml -n logging
```

```bash
kubectl get kibana -n logging

```

Check pods:

```bash
kubectl get po  -n logging
```

Lets create an `httproute` and `targetgroupconfiguration` for kibana so that we can expose it through gatewayAPI

**`observability/HTTProute-kibana.yaml`**

```bash
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: kibana-route
  namespace: logging
spec:
  hostnames:
    - "kibana.devopsdock.site"
  parentRefs:
  - group: gateway.networking.k8s.io
    namespace: default
    kind: Gateway
    name: app-alb-gateway
    sectionName: http
  - group: gateway.networking.k8s.io
    namespace: default
    kind: Gateway
    name: app-alb-gateway
    sectionName: https
  rules:
  - backendRefs:
    - name: eck-kibana-kb-http
      port: 5601
```

Take the `backendRefs` in `httproute` and `targetReference` in `targetgroupconfiguration` from the service:

```bash
kubectl get svc -n logging

NAME                                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
eck-elasticsearch-es-default         ClusterIP   None             <none>        9200/TCP   8h
eck-elasticsearch-es-http            ClusterIP   172.20.122.122   <none>        9200/TCP   8h
eck-elasticsearch-es-internal-http   ClusterIP   172.20.45.237    <none>        9200/TCP   8h
eck-elasticsearch-es-transport       ClusterIP   None             <none>        9300/TCP   8h
eck-kibana-kb-http                   ClusterIP   172.20.132.127   <none>        5601/TCP   11m
elastic-operator-webhook             ClusterIP   172.20.227.48    <none>        443/TCP    9h

```

**`observability/target-grp-kibana.yaml`**

 add health check

```bash
apiVersion: gateway.k8s.aws/v1beta1
kind: TargetGroupConfiguration
metadata:
  name: kibana-tg-config
  namespace: logging
spec:
  targetReference:
    name: eck-kibana-kb-http 
  defaultConfiguration:
    targetType: ip
    protocol: HTTPS
    healthCheckConfig:
      healthCheckProtocol: HTTPS
      healthCheckPath: /api/status
```

Now apply the files:

```bash
kubectl apply -f observability/HTTProute-kibana.yaml
```

```bash
kubectl apply -f observability/target-grp-kibana.yaml
```

Verify:

```bash
kubectl get httproute -n logging

```

```bash
kubectl get targetgroupconfiguration -n logging
```

```bash
kubectl get secret eck-elasticsearch-es-elastic-user -n logging -o go-template='{{.data.elastic | base64decode}}'
```

Go to discover section:

# Scaling & Reliability

We are using the microservices demo (Online Boutique style architecture), and we have a **`loadgenerator`** service.

Goal:

1. Use loadgenerator to generate traffic
2. Enable Horizontal Pod Autoscaler (HPA)
3. Observe scaling behavior
4. Validate reliability

Let’s do this properly, step by step.

---

### What Is Load Generator?

In the Online Boutique demo, `loadgenerator` continuously sends HTTP traffic to the `frontend` service.

So traffic flow:

```
loadgenerator → frontend → other services
```

Scaling will usually be applied to:

- frontend
- cartservice
- checkoutservice
- recommendationservice

---

### STEP 1 — Install metric server using helm

HPA requires metrics from Kubernetes

Run:

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
```

Install:

```bash
helm install metrics-server metrics-server/metrics-server --version 3.13.0 -n kube-system
```

Check if the pods are running:

```bash
kubectl get po -n kube-system | grep "metrics-server"
```

Confirm that metric server is working by running:

```bash
kubectl top nodes

kubectl top pods -n boutique-app

### STEP 2 — Verify Resource Requests Are Set

HPA needs CPU requests defined.

Check one service:

```bash
kubectl get deploy frontend -n boutique-app -o yaml | grep -A10 resources
```

output:

```bash
 resources:
          limits:
            cpu: 200m
            memory: 128Mi
          requests:
            cpu: 100m
            memory: 64Mi
```

### STEP 3 — Create HPA for Frontend

Start simple.

Create `scaling/frontend-hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-hpa
  namespace: boutique-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 1
  maxReplicas: 6
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 5
```
 kept the `averageUtilization` to 5.

Apply:

```bash
kubectl apply -f frontend-hpa.yaml
```

Check:

```bash
kubectl get hpa -n boutique-app
```

### STEP 4 — Increase Load (Not required in our case)

To increase load:

Edit the deployment:

```bash
kubectl edit deploy loadgenerator -n boutique-app
```

Find environment variable:

```
USERS
```

Increase it:

```yaml
-name:USERS value:"200"
```

Save.

This increases concurrent simulated users.

```bash
kubectl edit deploy loadgenerator -n boutique-app
```

**ArgoCD will detect drift and revert it back to the Helm-defined value.**

**That’s expected behavior in GitOps.**

---
We must modify the value in Git — not in the cluster.
>## HPA Configuration in a GitOps-Managed Environment
>
>Since the application is managed using GitOps (via Argo CD), all configuration changes must follow the Git workflow.
>### Correct Process
>
>1. Update the HPA configuration in the Helm values file.
>2. Commit and push the changes to the Git repository.
>3. Allow Argo CD to sync and apply the updated configuration to the cluster.
>
>---
>
>## Testing HPA Behavior
>
>For testing purposes, the `averageUtilization` was reduced from 50% to 5%.
>
>Setting such a low value ensures:
>
>- Even minimal CPU usage will exceed the threshold.
>- HPA will trigger scaling quickly.
>- It becomes easy to verify that autoscaling is functioning correctly.
>
>This configuration is **only for testing and demonstration purposes**.
>
>In a real production environment:
>
>- CPU thresholds would be carefully tuned.
>- Scaling decisions would be based on realistic load patterns.
>- Extremely low utilization targets like 5% would not be used.
>
>The goal here is simply to validate that the HPA mechanism is working as expected.
>


### STEP 5 — Watch Scaling
```bash
kubectl get hpa -n boutique-app -w
```
Terminal 2:

```bash
kubectl get pods -n boutique-app -w
```

### Validate CPU Trigger

Run:

```bash
kubectl top pods -n boutique-app
```

If CPU crosses 5% of the requests, replicas increase.

### Observe in Kibana

In Kibana:

Filter:

```
kubernetes.deployment.name: "frontend"
```

You’ll see more pods appearing.

You can even create a visualization showing replica count over time.

---

### STEP 6 — Add HPA for Other Services

---

Useful if you store images there.

```bash
echo <TOKEN> | docker login ghcr.io \
   -u USERNAME \
   --password-stdin
```

Tag/Retag your image:

```bash
docker tag us-central1-docker.pkg.dev/google-samples/microservices-demo/adservice:v0.10.4 ghcr.io/laxmikantagiri/microservices-demo/adservice:v0.10.4
```

Push the image:

```bash
  docker push ghcr.io/laxmikantagiri/microservices-demo/adservice:v0.10.4 
```

