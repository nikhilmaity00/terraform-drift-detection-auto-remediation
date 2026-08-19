# Terraform Drift Detection & Auto-Remediation Bot

A simple Terraform and Bash automation project that detects configuration drift in Google Cloud infrastructure, sends a webhook alert, and automatically remediates the drift using Terraform.

This project was built as a hands-on DevOps/IaC learning project using the KodeKloud GCP Playground.

---

## What is Infrastructure Drift?

Infrastructure drift happens when the actual cloud infrastructure becomes different from the configuration defined in Terraform.

For example:

```text
Terraform configuration:
drift_test = "original"

        ↓

Engineer manually changes GCP:
drift_test = "changed_manually"

        ↓

Actual infrastructure != Terraform configuration
```

Terraform can detect this difference during `terraform plan`.

This project automates that process.

---

## Project Workflow

```text
                 ┌──────────────────────┐
                 │      Linux Cron      │
                 └──────────┬───────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │ drift-detector.sh    │
                 └──────────┬───────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │ terraform plan      │
                 │ -detailed-exitcode  │
                 └──────────┬───────────┘
                            │
                 ┌──────────┴───────────┐
                 │                      │
               Exit 0                 Exit 2
                 │                      │
                 ▼                      ▼
             No drift             Drift detected
                                        │
                                        ▼
                                Webhook notification
                                        │
                                        ▼
                              terraform apply
                              -auto-approve
                                        │
                               ┌────────┴────────┐
                               │                 │
                            Success            Failure
                               │                 │
                               ▼                 ▼
                         Success alert     Failure alert
                                             + log file
```

---

## Technologies Used

* Terraform
* Google Cloud Platform (GCP)
* Bash
* Google Cloud CLI (`gcloud`)
* `curl`
* Webhooks
* Linux Cron
* KodeKloud GCP Playground

---

## Project Structure

```text
terraform-drift-detection-auto-remediation/
│
├── main.tf
├── variables.tf
├── terraform.tfvars
├── drift-detector.sh
├── .gitignore
└── README.md
```

Generated files such as Terraform state, plan output, and remediation logs are excluded from Git using `.gitignore`.

---

# Prerequisites

The following tools are required:

### Terraform

Check the installation:

```bash
terraform version
```

### Google Cloud CLI

Check the installation:

```bash
gcloud version
```

### Git

Check the installation:

```bash
git --version
```

### curl

Check the installation:

```bash
curl --version
```

---

# Google Cloud Authentication

This project uses the Google Cloud credentials provided by the KodeKloud GCP Playground.

First verify that you are signed in:

```bash
gcloud auth list
```

You should see an active KodeKloud account.

Example:

```text
Credentialed Accounts

ACTIVE  ACCOUNT
*       kk_lab_user_xxxxx@kkgcplabs02.com
```

Verify the active project:

```bash
gcloud config get-value project
```

Example:

```text
kkgcplabs01-038
```

The Terraform provider requires a Google OAuth access token.

The project obtains a temporary token using:

```bash
gcloud auth print-access-token
```

The drift detection script exports this token automatically:

```bash
export TF_VAR_gcp_token="$(gcloud auth print-access-token)"
```

This means the token does not need to be stored in the Terraform files.

> Note: KodeKloud playground credentials are temporary. The authentication approach in this project is intended for the lab environment and is not presented as a production authentication architecture.

---

# Terraform Configuration

The Terraform configuration creates a Google Cloud Storage bucket.

The bucket contains labels that make it easy to demonstrate configuration drift.

Example:

```hcl
labels = {
  drift_test = "original"
  env        = "lab"
  managed_by = "terraform"
}
```

Terraform considers `original` to be the desired configuration.

---

# Initial Setup

Clone the repository:

```bash
git clone git@github.com:nikhilmaity00/terraform-drift-detection-auto-remediation.git
```

Change into the project directory:

```bash
cd terraform-drift-detection-auto-remediation
```

Initialize Terraform:

```bash
terraform init
```

Validate the configuration:

```bash
terraform validate
```

Create the infrastructure:

```bash
terraform apply
```

Review the proposed changes and enter:

```text
yes
```

---

# Verify the Initial State

Run:

```bash
terraform plan -detailed-exitcode
```

A clean environment should return:

```text
No changes.
```

The exit code should be:

```text
0
```

Check it with:

```bash
echo $?
```

---

# Understanding Terraform Exit Codes

The drift detection script uses Terraform's `-detailed-exitcode` option.

| Exit Code | Meaning                                                           |
| --------- | ----------------------------------------------------------------- |
| `0`       | Terraform plan completed successfully and no changes are required |
| `1`       | Terraform encountered an error                                    |
| `2`       | Terraform plan completed successfully and changes were detected   |

For this learning project, exit code `2` is treated as a drift event.

---

# Simulating Configuration Drift

To demonstrate the project, manually change the GCP resource outside Terraform.

Open the GCP Console and navigate to:

```text
Cloud Storage
    ↓
Buckets
    ↓
kkgcplabs01-038-drift-check-resource
```

Modify the label:

```text
drift_test = original
```

to:

```text
drift_test = changed_manually
```

Save the change.

Do not modify the Terraform configuration.

---

# Test Drift Detection

Run:

```bash
./drift-detector.sh
```

The script will:

1. Refresh the temporary Google Cloud authentication token.
2. Run `terraform plan -detailed-exitcode`.
3. Capture the Terraform exit code.
4. Detect the drift.
5. Send a webhook notification.
6. Automatically run Terraform remediation.

Terraform should identify a change similar to:

```text
"drift_test" = "changed_manually" -> "original"
```

---

# Webhook Configuration

The project uses a generic webhook for notifications.

For testing, a service such as Webhook.site can be used.

Create a temporary webhook URL and export it:

```bash
export WEBHOOK_URL="https://webhook.site/your-unique-url"
```

Verify that it is configured:

```bash
if [ -n "$WEBHOOK_URL" ]; then
    echo "Webhook configured"
else
    echo "Webhook missing"
fi
```

The script sends notifications when:

* Drift is detected
* Remediation succeeds
* Remediation fails

The webhook URL is stored in an environment variable rather than in the script.

---

# Auto-Remediation

When Terraform returns exit code `2`, the script runs:

```bash
terraform apply -auto-approve
```

Terraform then changes the resource back to the configuration defined in the `.tf` files.

For example:

```text
GCP actual state:

drift_test = changed_manually

        ↓

Terraform remediation

        ↓

Desired state:

drift_test = original
```

---

# Remediation Failure Handling

The script also handles failed remediation attempts.

Terraform apply output is captured in:

```text
remediation_output.txt
```

If remediation fails, the script records the failure information in:

```text
remediation_failed.log
```

The failure log includes:

* Timestamp
* Terraform apply exit code
* Terraform plan output
* Terraform apply output

A failure webhook notification is also sent.

This provides basic troubleshooting evidence instead of silently failing.

---

# Verify Remediation

After the script completes, run:

```bash
terraform plan -detailed-exitcode
```

A successful remediation should return:

```text
No changes.
```

Then:

```bash
echo $?
```

should return:

```text
0
```

This confirms that the infrastructure is back in sync with the Terraform configuration.

---

# Linux Cron

The final stage of the project is to run the drift detection script automatically.

For example, to run it every 15 minutes:

```cron
*/15 * * * * cd /path/to/terraform-drift-detection-auto-remediation && ./drift-detector.sh >> drift-cron.log 2>&1
```

Check the configured cron jobs with:

```bash
crontab -l
```

The automated workflow becomes:

```text
Every 15 minutes
       ↓
drift-detector.sh
       ↓
terraform plan
       ↓
No drift → exit
       ↓
Drift → webhook
       ↓
terraform apply
       ↓
Success / Failure notification
```

---

# Important Notes

## KodeKloud Playground

This project was designed to run within the KodeKloud GCP Playground.

The playground environment is temporary, so:

* GCP credentials are temporary.
* The GCP project is provided by KodeKloud.
* Resources should be treated as lab resources.
* The environment may expire or reset.