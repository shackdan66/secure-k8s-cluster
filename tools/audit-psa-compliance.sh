#!/bin/bash
# audit-psa-compliance.sh

NAMESPACE=${1:-""}
POLICY_LEVEL=${2:-"restricted"}  # baseline, restricted, privileged

if [ -z "$NAMESPACE" ]; then
    echo "Usage: $0 <namespace> [policy-level]"
    echo "Example: $0 production restricted"
    exit 1
fi

echo "=== PSA Compliance Audit for namespace: $NAMESPACE ==="
echo "Policy Level: $POLICY_LEVEL"

# Create output directory
OUTPUT_DIR="psa-audit-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

# Function to check pod security compliance
check_pod_security() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    
    echo "Checking $resource_type/$resource_name..."
    
    # Get pod template
    local pod_spec
    if [ "$resource_type" = "deployment" ]; then
        pod_spec=$(kubectl get deployment $resource_name -n $namespace -o jsonpath='{.spec.template.spec}')
    elif [ "$resource_type" = "daemonset" ]; then
        pod_spec=$(kubectl get daemonset $resource_name -n $namespace -o jsonpath='{.spec.template.spec}')
    elif [ "$resource_type" = "statefulset" ]; then
        pod_spec=$(kubectl get statefulset $resource_name -n $namespace -o jsonpath='{.spec.template.spec}')
    else
        return
    fi
    
    # Check for common PSA violations
    local violations=()
    
    # Check for privileged containers
    if echo "$pod_spec" | jq -e '.containers[]? | select(.securityContext.privileged == true)' >/dev/null 2>&1; then
        violations+=("privileged-container")
    fi
    
    # Check for hostNetwork
    if echo "$pod_spec" | jq -e 'select(.hostNetwork == true)' >/dev/null 2>&1; then
        violations+=("host-network")
    fi
    
    # Check for hostPID
    if echo "$pod_spec" | jq -e 'select(.hostPID == true)' >/dev/null 2>&1; then
        violations+=("host-pid")
    fi
    
    # Check for hostIPC
    if echo "$pod_spec" | jq -e 'select(.hostIPC == true)' >/dev/null 2>&1; then
        violations+=("host-ipc")
    fi
    
    # Check for privileged escalation
    if echo "$pod_spec" | jq -e '.containers[]? | select(.securityContext.allowPrivilegeEscalation == true)' >/dev/null 2>&1; then
        violations+=("privilege-escalation")
    fi
    
    # Check for running as root
    if echo "$pod_spec" | jq -e '.containers[]? | select(.securityContext.runAsUser == 0 or (.securityContext.runAsUser | not))' >/dev/null 2>&1; then
        violations+=("run-as-root")
    fi
    
    # Check for capabilities
    if echo "$pod_spec" | jq -e '.containers[]?.securityContext.capabilities.add[]?' >/dev/null 2>&1; then
        violations+=("added-capabilities")
    fi
    
    # Check for host ports
    if echo "$pod_spec" | jq -e '.containers[]?.ports[]? | select(.hostPort)' >/dev/null 2>&1; then
        violations+=("host-ports")
    fi
    
    # Check for volume types (for restricted policy)
    if [ "$POLICY_LEVEL" = "restricted" ]; then
        if echo "$pod_spec" | jq -e '.volumes[]? | select(.hostPath or .nfs or .iscsi or .glusterfs or .rbd or .flexVolume or .cinder or .cephfs or .flocker or .fc or .azureFile or .vsphereVolume or .quobyte or .azureDisk or .portworxVolume or .scaleIO or .storageos)' >/dev/null 2>&1; then
            violations+=("restricted-volume-types")
        fi
    fi
    
    # Output results
    if [ ${#violations[@]} -gt 0 ]; then
        echo "$namespace,$resource_type,$resource_name,NON-COMPLIANT,${violations[*]}" >> "$OUTPUT_DIR/violations.csv"
        return 1
    else
        echo "$namespace,$resource_type,$resource_name,COMPLIANT," >> "$OUTPUT_DIR/violations.csv"
        return 0
    fi
}

# Create CSV header
echo "Namespace,Resource_Type,Resource_Name,Status,Violations" > "$OUTPUT_DIR/violations.csv"

# Check deployments
echo "=== Checking Deployments ==="
kubectl get deployments -n $NAMESPACE -o name | while read -r deployment; do
    deployment_name=$(echo $deployment | cut -d'/' -f2)
    check_pod_security "deployment" "$deployment_name" "$NAMESPACE"
done

# Check daemonsets
echo "=== Checking DaemonSets ==="
kubectl get daemonsets -n $NAMESPACE -o name | while read -r daemonset; do
    daemonset_name=$(echo $daemonset | cut -d'/' -f2)
    check_pod_security "daemonset" "$daemonset_name" "$NAMESPACE"
done

# Check statefulsets
echo "=== Checking StatefulSets ==="
kubectl get statefulsets -n $NAMESPACE -o name | while read -r statefulset; do
    statefulset_name=$(echo $statefulset | cut -d'/' -f2)
    check_pod_security "statefulset" "$statefulset_name" "$NAMESPACE"
done

echo "=== Audit Results ==="
echo "Results saved to: $OUTPUT_DIR/violations.csv"

# Display summary
total_resources=$(tail -n +2 "$OUTPUT_DIR/violations.csv" | wc -l)
non_compliant=$(tail -n +2 "$OUTPUT_DIR/violations.csv" | grep "NON-COMPLIANT" | wc -l)
compliant=$(tail -n +2 "$OUTPUT_DIR/violations.csv" | grep "COMPLIANT" | wc -l)

echo "Total Resources Checked: $total_resources"
echo "Compliant: $compliant"
echo "Non-Compliant: $non_compliant"

if [ $non_compliant -gt 0 ]; then
    echo -e "\n=== Non-Compliant Resources ==="
    tail -n +2 "$OUTPUT_DIR/violations.csv" | grep "NON-COMPLIANT" | while IFS=',' read -r namespace resource_type resource_name status violations; do
        echo "- $resource_type/$resource_name: $violations"
    done
fi