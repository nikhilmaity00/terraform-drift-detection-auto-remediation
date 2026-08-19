#!/bin/bash

#ensure gcloud cli is authenticated for the below line to pass the access token
export TF_VAR_gcp_token="$(gcloud auth print-access-token)"

terraform plan -detailed-exitcode -no-color > plan_output.txt 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "No drift detected."
    exit 0

elif [ $EXIT_CODE -eq 2 ]; then
    echo "DRIFT DETECTED!"
    echo
    echo "Terraform changes:"
    cat plan_output.txt
    curl -X POST \
      -H "Content-Type: application/json" \
      -d '{"text":"Terraform Drift Detected! Check plan_output.txt for details."}' \
      "$WEBHOOK_URL"
    echo
    echo "Starting Terraform auto-remediation..."

    terraform apply -auto-approve > remediation_output.txt 2>&1
    APPLY_EXIT_CODE=$?

    if [ $APPLY_EXIT_CODE -eq 0 ]; then
        echo "Drift successfully remediated."
        curl -X POST \
        -H "Content-Type: application/json" \
        -d '{"text":"Terraform Drift successfully remediated."}' \
        "$WEBHOOK_URL"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Remediation successful." >> remediation.log
        exit 0

    else
        echo "Terraform remediation FAILED."
        echo "Check remediation_failed.log"
        {
            echo "================================="
            echo "Remediation failed: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Exit code: $APPLY_EXIT_CODE"
            echo
            echo "----- Terraform Plan -----"
            cat plan_output.txt
            echo
            echo "----- Terraform Apply Output -----"
            cat remediation_output.txt
            echo
        } >> remediation_failed.log
        curl -X POST \
        -H "Content-Type: application/json" \
        -d '{"text":"CRITICAL: Terraform Drift remediation FAILED. Check remediation_failed.log."}' \
        "$WEBHOOK_URL"
        exit 1
    fi

else
    echo "Terraform plan failed."
    echo
    cat plan_output.txt
    exit 1
fi