# AWS Marketplace - Helm Chart offering

## AWS Marketplace Server Product

An AWS Helm Chart Marketplace offering is created as a `Server Product`. Go to [Server Products](https://aws.amazon.com/marketplace/management/products/server) and create a new Server product of type `container`.

### AWS Marketplace ECR Repositories

Once the product is created, click on "Request Changes" and "Add repositories". For each image that is part of your Helm Chart, you'll need to create a corresponding repository. Example structure:

```
709825985650.dkr.ecr.us-east-1.amazonaws.com/slackernews/spooky
709825985650.dkr.ecr.us-east-1.amazonaws.com/slackernews/spooky/nginx
709825985650.dkr.ecr.us-east-1.amazonaws.com/slackernews/spooky/busybox
709825985650.dkr.ecr.us-east-1.amazonaws.com/slackernews/spooky/replicated-sdk-image
709825985650.dkr.ecr.us-east-1.amazonaws.com/slackernews/spooky-app
709825985650.dkr.ecr.us-east-1.amazonaws.com/slackernews/spooky/curlimages/curl
```

## Helm Chart

Under [spooky/spooky-app](.spooky/spooky-app/) there is an example Helm chart we'll use for an AWS Marketplace offering as a Helm Chart.
In order to make a Helm Chart ready for the AWS Marketplace in combination with Replicated licensing, the following must be taken into consideration.

1. Replicated SDK
Add the replicated sdk as a Helm dependency to your chart.
See the implementation in [`spooky/spooky-app/Chart.yaml`](spooky/spooky-app/Chart.yaml).

```
dependencies:
- name: replicated
  repository: oci://registry.replicated.com/library
  version: 1.15.0
```

2. Reference images in values.yaml
In order for AWS to accept the Helm Chart, all images must be referenced via the default [values.yaml](spooky/spooky-app/values.yaml). Our Helm Chart is using `nginx` in the deployment, and as such we need to put the image as values in the `values.yaml`:
```
nginx:
  image:
    repository: 709825985650.dkr.ecr.us-east-1.amazonaws.com/slackernews/spooky/nginx
    pullPolicy: IfNotPresent
    # Overrides the image tag whose default is the chart appVersion.
    tag: 1.29.5
```

Notice the `repository` which points to the ECR Marketplace repository. Once you have created the marketplace application, you'll be able to add repositories for each image in your Helm Chart. Those repositories must be used inside the [values.yaml](spooky/spooky-app/values.yaml) of your Helm Chart.

3. Add license validation logic

Ensure you add logic to your application that will [validate the license using the sdk](https://docs.replicated.com/reference/replicated-sdk-apis#revoke-access-at-runtime-when-a-license-expires). You can also use an init container as part of your application, although that will be less secure. An example can be found in [deployment.yaml](spooky/spooky-app/templates/deployment.yaml):
```
  - name: license-validator
    image: "{{ .Values.curl.image.repository }}:{{ .Values.curl.image.tag }}"
    imagePullPolicy: {{ .Values.curl.image.pullPolicy }}
    command: ["/bin/sh"]
    args:
    - -c
    - |
        echo "Validating license expiration..."

        # Fetch license expiration date from Replicated SDK
        RESPONSE=$(curl -sf http://replicated:3000/api/v1/license/fields/expires_at)
        if [ $? -ne 0 ]; then
        echo "ERROR: Unable to connect to Replicated SDK"
        exit 1
        fi

        # Extract the expires_at value from JSON response
        EXPIRES_AT=$(echo "$RESPONSE" | grep -o '"value":"[^"]*"' | cut -d'"' -f4)

        if [ -z "$EXPIRES_AT" ]; then
        echo "ERROR: Unable to retrieve license expiration date"
        exit 1
        fi

        echo "License expires at: $EXPIRES_AT"

        # Convert dates to epoch for comparison
        # BusyBox date (used in Alpine/curlimages) requires -D for input format
        # Strip the 'Z' suffix and parse the ISO 8601 format
        EXPIRES_AT_STRIPPED=${EXPIRES_AT%Z}
        EXPIRES_EPOCH=$(date -D "%Y-%m-%dT%H:%M:%S" -d "$EXPIRES_AT_STRIPPED" +%s 2>/dev/null)
        CURRENT_EPOCH=$(date +%s)

        if [ -z "$EXPIRES_EPOCH" ]; then
        echo "ERROR: Unable to parse expiration date"
        exit 1
        fi

        # Check if license has expired
        if [ "$CURRENT_EPOCH" -gt "$EXPIRES_EPOCH" ]; then
        echo "ERROR: License has expired on $EXPIRES_AT"
        exit 1
        fi

        DAYS_REMAINING=$(( ($EXPIRES_EPOCH - $CURRENT_EPOCH) / 86400 ))
        echo "License is valid. Days remaining: $DAYS_REMAINING"
        exit 0
    securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    allowPrivilegeEscalation: false
    capabilities:
        drop:
        - ALL
```

## Package and Promote your Application

1. Package Helm Chart
Package your helm chart, and copy it over to the location that has your Replicated Manifests. Example:

```
HELM_VERSION=0.1.11
cd spooky
helm package spooky-app -u -d manifests --app-version=$HELM_VERSION --version=$HELM_VERSION
```

2. Create HelmChart specification

Create your `kind: HelmChart` specification and ensure it has the `builder` values configured to pull all your images from your Helm Chart to create the air gap bundle. An example can be found under [spooky/manifests/spooky-app-chart.yaml](spooky/manifests/spooky-app-chart.yaml).

```
  builder:
    nginx:
      image:
        repository: nginx
        tag: 1.29.5
    busybox:
      image:
        repository: busybox
        tag: 1.37.0
    curl:
      image:
        repository: curlimages/curl
        tag: 8.5.0
    replicated:
      image:
        registry: proxy.replicated.com 
        repository: library/replicated-sdk-image
```

Also ensure that the `chartVersion` matches the version used for `$HELM_VERSION`.
```
  # chart identifies a matching chart from a .tgz
  chart:
    name: spooky-app
    chartVersion: 0.1.11
```


3. Create and Promote Release

Prerequisites:
* You have an application defined in vendor.replicated.com
* You have the replicated cli configured
* You have a channel for your application called `aws-marketplace`, which has the setting to automatically create Air Gap builds enabled.
* You have Enterprise Portal enabled and [Self-Service Sign-Ups](https://docs.replicated.com/vendor/enterprise-portal-self-serve-signup)


Next is packaging your application, so that Replicated can create the air gap bundle and generate a list of all the image we'll have to push to the Marketplace ECR registry.
```
cd manifests
replicated release create --yaml-dir . --promote aws-marketplace --version <REPLICATED_VERSION>
```

4. Create a Development Customer

In the vendor portal, create a new customer assigned to the `aws-marketplace` channel and enable `Helm CLI` and `Helm CLI Air Gap Instructions` options.

## Push artifacts to Marketplace ECR Registry

1. Images

If not done yet, ensure you have logged in into the ecr marketplace registry using docker:

```
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com
```

Go to the Replicated Enterprise Portal for that customer, click on Install and select `No outbound requests allowed (air gap)` and `My workstation can access the internet, the registry AND the cluster`. Follow the instructions 1 to 4 to pull, tag and push each image to the ECR marketplace repository.

2. Helm chart

If not done yet, ensure you have logged in into the ecr marketplace registry using Helm:

```
aws ecr get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com
```

Push the Helm chart to the ECR Marketplace registry:

```
helm push spooky-app-0.1.11.tgz oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/slackernews
```

## Create AWS Marketplace version

Go to your [AWS Marketplace Server Product](https://aws.amazon.com/marketplace/management/products/server) and click on "Request Changes" > "Update versions" > "Add new version".
Configure the following:
* Version title
* Release notes
* Select "Helm" Delivery option
* Select "Amazon Elastic Kubernetes Service (EKS)"
* Add your Helm chart repo/tag and any images from your Helm Chart.
* Usage instructions: Example:

````markdown
1. Register for a trial
* Browse to [https://enterprise.replicated.com/marketplace-helm/signup](https://enterprise.replicated.com/marketplace-helm/signup) and signup.
* Go to "Install", specify an instance name and click "Continue"
* Copy the "Export credentials and log in" command and run it. It will look like
```
export AUTH_TOKEN=e******************************
helm registry login registry.replicated.com --username <YOUR_EMAIL> --password $AUTH_TOKEN
```

2. Login into AWS ECR registry
```
aws ecr get-login-password \
    --region us-east-1 | helm registry login \
    --username AWS \
    --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com

mkdir awsmp-chart && cd awsmp-chart

helm pull oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/slackernews/spooky-app --version 0.1.11
```

3. Get the values file
```
helm show values oci://registry.replicated.com/marketplace-helm/aws-marketplace/spooky-app \
    --version 0.1.11 > values-replicated.yaml
```

4. Install the Helm chart
```
helm install spooky-app spooky-app-0.1.11.tgz --namespace spooky --create-namespace \
    --values values-replicated.yaml 
```
````

Submit the new version and wait for it to be reviewed (can take 45 minutes).