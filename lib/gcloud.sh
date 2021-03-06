#!/usr/bin/env bash

set -eu

######################################################
# Delete old versions of service on Google App Engine.
#
# Arguments:
#   1 the name of the service on GAE
#   2 the maximum number of versions to keep on GAE
######################################################
delete_old_versions() {
  local service=$1
  local max_service_versions=$2
  local ids=()
  local limit=0

  echo ""
  echo "Checking number of versions for $service service"
  readarray -t ids < <(gcloud app versions list \
    --service="$service" \
    --filter="version.servingStatus=stopped" \
    --format="table[no-heading](version.id)")

  if [ "${#ids[@]}" -le "$max_service_versions" ]; then
    echo "No old versions to delete"
    return 0;
  fi

  limit=$((${#ids[@]} - max_service_versions))

  echo "Deleting $limit old versions"
  for version in "${ids[@]::limit}"
  do
    gcloud app versions delete --service="$service" "$version"
  done
}

######################################################
# Stop previous versions of service on Google App Engine.
#
# Arguments:
#   1 the name of the service on GAE
######################################################
stop_previous_versions() {
    echo -e "\nStopping all previous serving versions of $1"
    # Fetch all previous serving versions sorted by creation time in desc. order.
    # Remove headings and start from second line.
    local ids=$(gcloud app versions list --service $1 \
        --filter="version.servingStatus=serving" \
        --sort-by="~version.createTime" \
        --format="table[no-heading](version.id)" | tail -n +2)
    for version in $ids
    do
        echo -e "\nStopping version"
        gcloud -q --verbosity=debug app versions stop --service $1 "${version}"
    done
}
