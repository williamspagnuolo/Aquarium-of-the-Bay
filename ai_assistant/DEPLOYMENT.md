# Aquarium Analytics Assistant Deployment

## Overview

The Aquarium Analytics Assistant is deployed as a containerized Streamlit application on Google Cloud Run.

The deployed service uses:

* Cloud Run for application hosting
* Artifact Registry for Docker images
* Cloud Build for container builds
* Vertex AI for Gemini
* BigQuery for analytics queries
* Identity-Aware Proxy for user authentication

## Prerequisites

Required Google Cloud APIs:

```text
aiplatform.googleapis.com
bigquery.googleapis.com
run.googleapis.com
cloudbuild.googleapis.com
artifactregistry.googleapis.com
iap.googleapis.com
```

Enable them with:

```bash
gcloud services enable \
aiplatform.googleapis.com \
bigquery.googleapis.com \
run.googleapis.com \
cloudbuild.googleapis.com \
artifactregistry.googleapis.com \
iap.googleapis.com
```

On Windows Command Prompt, place the services on one line.

## Service Account

The Cloud Run service uses a dedicated service account:

```text
aquarium-ai-assistant@rocket-rez-api.iam.gserviceaccount.com
```

Required permissions include:

### Project-level

```text
BigQuery Job User
Vertex AI User
```

### Dataset-level

On:

```text
rocket_rez_ai
```

grant:

```text
BigQuery Data Viewer
```

The service account should not receive direct read access to `rocket_rez_data`.

## Artifact Registry

Create the Docker repository if it does not already exist:

```bash
gcloud artifacts repositories create aquarium-ai \
  --repository-format=docker \
  --location=us-central1 \
  --description="Aquarium AI Assistant containers"
```

## Build

From the `ai_assistant` directory:

```bash
gcloud builds submit \
  --tag us-central1-docker.pkg.dev/rocket-rez-api/aquarium-ai/aquarium-analytics-assistant:latest .
```

The Docker image is stored in Artifact Registry.

## Deploy

Deploy the service:

```bash
gcloud run deploy aquarium-analytics-assistant \
  --image us-central1-docker.pkg.dev/rocket-rez-api/aquarium-ai/aquarium-analytics-assistant:latest \
  --region us-central1 \
  --service-account aquarium-ai-assistant@rocket-rez-api.iam.gserviceaccount.com \
  --no-allow-unauthenticated
```

## Identity-Aware Proxy

The service is protected with IAP.

Enable IAP:

```bash
gcloud run services update aquarium-analytics-assistant \
  --region us-central1 \
  --iap
```

A custom OAuth client is required because the project is not part of a Google Cloud Organization.

The OAuth redirect URI must follow this pattern:

```text
https://iap.googleapis.com/v1/oauth/clientIds/CLIENT_ID:handleRedirect
```

The OAuth client configuration is applied through an `iap_settings.yaml` file.

Example:

```yaml
access_settings:
  oauth_settings:
    client_id: YOUR_CLIENT_ID
    client_secret: YOUR_CLIENT_SECRET
```

Apply it with:

```bash
gcloud iap settings set iap_settings.yaml --project=rocket-rez-api
```

`iap_settings.yaml` must never be committed to GitHub.

## Grant User Access

Approved users need the following role:

```text
IAP-Secured Web App User
```

Underlying IAM role:

```text
roles/iap.httpsResourceAccessor
```

Example:

```bash
gcloud iap web add-iam-policy-binding \
  --member="user:user@example.com" \
  --role="roles/iap.httpsResourceAccessor" \
  --region=us-central1 \
  --resource-type=cloud-run \
  --service=aquarium-analytics-assistant \
  --project=rocket-rez-api
```

Users can also be managed through the Google Cloud IAP interface.

## Redeployment

After application changes:

```bash
gcloud builds submit \
  --tag us-central1-docker.pkg.dev/rocket-rez-api/aquarium-ai/aquarium-analytics-assistant:latest .
```

Then redeploy:

```bash
gcloud run deploy aquarium-analytics-assistant \
  --image us-central1-docker.pkg.dev/rocket-rez-api/aquarium-ai/aquarium-analytics-assistant:latest \
  --region us-central1 \
  --service-account aquarium-ai-assistant@rocket-rez-api.iam.gserviceaccount.com
```

Cloud Run creates a new revision while retaining previous revisions for rollback.

## Secrets and Local Files

Do not commit:

```text
iap_settings.yaml
OAuthSecretID.json
.env
.env.*
.venv/
.streamlit/secrets.toml
```

These should remain covered by `.gitignore`.

## Validation After Deployment

After deploying, confirm:

1. The Cloud Run URL redirects to Google login.
2. Only approved IAP users can access the application.
3. Gemini successfully generates SQL.
4. The SQL validator accepts only approved views.
5. BigQuery queries execute successfully.
6. Results match trusted Power BI dashboard metrics.
7. Attempts to access protected PII or `rocket_rez_data` directly are rejected.
