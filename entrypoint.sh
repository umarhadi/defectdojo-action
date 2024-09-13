#!/usr/bin/bash

set -e

if [[ -z "$DEFECTDOJO_TOKEN" ]]; then
    echo "ERROR: You must provide a valid DefectDojo token!"
    exit 1
fi

if [[ -z "$DEFECTDOJO_URL" ]]; then
    echo "ERROR: You must provide a valid DefectDojo url. Example: https://defectdojo.example.com"
    exit 1
fi
if [[ -z "$DEFECTDOJO_PRODUCT_TYPE" ]]; then
    echo "ERROR: Specify the productType name!"
    exit 1
fi
if [[ -z "$DEFECTDOJO_PRODUCT" ]]; then
    echo "ERROR: Specify the product name!"
    exit 1
fi
if [[ -z "$DEFECTDOJO_ENGAGEMENT" ]]; then
    echo "ERROR: Pass the name of engagement - e.g. branch name!"
    exit 1
fi
if [[ -z "$DEFECTDOJO_ENVIRONMENT" ]]; then
    echo "ERROR: Pass the name of environment!"
    exit 1
fi
if [[ -z "$DEFECTDOJO_TOOLS" ]]
then
    echo "ERROR: Pass the list of integrated tools!"
    exit 1
fi

productType=$(curl -X GET "$DEFECTDOJO_URL/api/v2/product_types/?name=$DEFECTDOJO_PRODUCT_TYPE" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" -H "Content-Type: application/json" | jq -r '.results' | jq -r '.[0].id')

if [[ -z "$productType" ]]; then
    echo "Product Type does not exist! You need to create it in DefectDojo or specify the valid value"
    exit 1
fi


product=$(curl -X GET "$DEFECTDOJO_URL/api/v2/products/?name=$DEFECTDOJO_PRODUCT" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" -H "Content-Type: application/json" | jq -r '.results' | jq -r '.[0].id')

if [[ -z "$product" ]]; then
    echo "Creating product $DEFECTDOJO_PRODUCT in DefectDojo"
    JSON='{"name": "'$DEFECTDOJO_PRODUCT'", "description": "Project '$DEFECTDOJO_PRODUCT'", "prod_type": "'$productType'"}'
    JSON=$(echo "$JSON" | sed -e 's/,}/}/g')

    product=$(curl -X POST "$DEFECTDOJO_URL/api/v2/products/" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" -H "Content-Type: application/json" -d "$JSON" | jq -r '.id')
fi

engagement=$(curl -X GET "$DEFECTDOJO_URL/api/v2/engagements/?name=$DEFECTDOJO_ENGAGEMENT&product=$product" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" -H "Content-Type: application/json" | jq -r '.results' | jq -r '.[0].id')

if [[ -z "$engagement" ]]; then
    echo "Creating engagement $DEFECTDOJO_ENGAGEMENT for product $DEFECTDOJO_PRODUCT in DefectDojo"
    start_date=$(date '+%Y-%m-%d')
    end_date=$(date '+%Y-%m-%d' -d '+21 days')

    JSON='{"name": "'$DEFECTDOJO_ENGAGEMENT'", "description": "Engagements for '$DEFECTDOJO_PRODUCT', branch '$DEFECTDOJO_ENGAGEMENT'", "product": "'$product'", "deduplication_on_engagement": "true", "branch_tag": "'$DEFECTDOJO_ENGAGEMENT'", "threat_model": "true", "api_test": "true", "pen_test": "true", "check_list": "true", "status": "In Progress", "engagement_type": "CI/CD", "target_start": "'$start_date'", "target_end": "'$end_date'"}'
    JSON=$(echo "$JSON" | sed -e 's/,}/}/g')

    engagement=$(curl -X POST "$DEFECTDOJO_URL/api/v2/engagements/" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" -H "Content-Type: application/json" -d "$JSON" | jq -r '.id')
fi

environment=$(curl -X GET "$DEFECTDOJO_URL/api/v2/development_environments/" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" -H "Content-Type: application/json" | jq -r '.results' | jq -r 'first(.[].name)')
if [[ -z "$environment" ]]; then
    echo "Creating $DEFECTDOJO_ENVIRONMENT environment"

    JSON='{"name": "'$DEFECTDOJO_ENVIRONMENT'"}'
    JSON=$(echo "$JSON" | sed -e 's/,}/}/g')

    environment=$(curl -X POST "$DEFECTDOJO_URL/api/v2/development_environments/" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" -H "Content-Type: application/json" -d "$JSON" | jq -r '.name')
fi

IFS=',' read -r -a testsArray <<< "$DEFECTDOJO_TOOLS"
for testName in "${testsArray[@]}"; do
    sonarApiScan=""
    testID=$(curl -X GET "$DEFECTDOJO_URL/api/v2/test_types/?name=${testName// /%20}" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" -H "Content-Type: application/json" | jq -r '.results' | jq -r '.[0].id')
    if [[ -z "$testID" ]]; then
        echo "Test $testName does not exist! Check you configuration"
        exit 1
    fi
    echo "$testName with id $testID"
    if [ "$testName" = 'SonarQube API Import' ]; then
        sonarTool=$(curl -X GET "$DEFECTDOJO_URL/api/v2/tool_configurations/?name=SonarQube" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" -H "Content-Type: application/json" | jq -r '.results' | jq -r '.[0].id')
        if [ -z "$sonarTool" ]; then
            echo "ERROR: There is no configured SonarQube tool!"
            exit 1
        fi
        if [[ -z "$DEFECTDOJO_SONAR_KEY" ]]; then
            echo "ERROR: Specify sonar.productKey to integrate with SonarQube"
            exit 1
        fi
        sonarApiScan=$(curl -X GET "$DEFECTDOJO_URL/api/v2/product_api_scan_configurations/?product=$product&service_key_1=$DEFECTDOJO_SONAR_KEY" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" -H "Content-Type: application/json" | jq -r '.results' | jq -r '.[0].id')
        if [ -z "$sonarApiScan" ]; then
            echo "Creating SonarQube API scan for $DEFECTDOJO_PRODUCT product"

            JSON='{"service_key_1": "'$DEFECTDOJO_SONAR_KEY'", "tool_configuration":"'$sonarTool'", "product": "'$product'"}'
            JSON=$(echo "$JSON" | sed -e 's/,}/}/g')
            sonarApiScan=$(curl -X POST "$DEFECTDOJO_URL/api/v2/product_api_scan_configurations/" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" -H "Content-Type: application/json" -d "$JSON" | jq -r '.id')
            echo $sonarApiScan
        fi
    fi
    if [ "$testName" = 'Github Vulnerability Scan' ]; then
        if [[ -z "$DEFECTDOJO_GITHUB_TOKEN" ]]; then
            echo "ERROR: Specify Github Token to access vulnerability information!"
            exit 1
        fi
        if [[ -z "$DEFECTDOJO_GITHUB_REPO" ]]; then
            echo "ERROR: specify Github Repository - owner/repo"
            exit 1
        fi
        githubOrg=$(echo $DEFECTDOJO_GITHUB_REPO | cut -d "/" -f 1)
        repositoryName=$(echo $DEFECTDOJO_GITHUB_REPO | cut -d "/" -f 2)
        query='query getVulnerabilitiesByRepoAndOwner($name: String!, $owner: String!) { repository(name: $name, owner: $owner) { vulnerabilityAlerts(first: 100) { nodes { id createdAt vulnerableManifestPath securityVulnerability { severity package { name ecosystem } advisory { description summary identifiers { value type } references { url } cvss { vectorString } } } vulnerableManifestPath }}}}'
        $(curl -X POST 'https://api.github.com/graphql' \
                    -H "Authorization: Bearer $DEFECTDOJO_GITHUB_TOKEN" \
                    -H "Content-Type: application/json" \
                    -d "{ \"query\": \"$query\", \"variables\": {\"name\": \"$repositoryName\", \"owner\": \"$githubOrg\" } }" \
                    > github.json)
    fi
    test=$(curl -X GET "$DEFECTDOJO_URL/api/v2/tests/?title=${testName// /%20}&engagement=$engagement" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" -H "Content-Type: application/json" | jq -r '.results' | jq -r '.[0].id')
    if ! [[ -z "$test" ]]; then
        $(curl -X DELETE "$DEFECTDOJO_URL/api/v2/tests/$test/" -H "Authorization: Token $DEFECTDOJO_TOKEN" -H "accept: application/json" )
    fi
    report=$( echo $DEFECTDOJO_REPORTS | jq -r --arg var "$testName" '.[$var]')
    if [[ $report == null ]]; then
        if [[ -z "$sonarApiScan" || $sonarApiScan == "" ]]; then
            echo 'ERROR: You need to specify the report! As JSON {"Acunetix Scan": "report.json"}! Do not forget to check supported format'
            exit 1
        else
            curl -X POST "$DEFECTDOJO_URL/api/v2/import-scan/" \
                -H "Authorization: Token $DEFECTDOJO_TOKEN" \
                -H "accept: application/json" \
                -H "Content-Type: multipart/form-data" \
                -F "engagement=$engagement" \
                -F "scan_type=$testName" \
                -F "test_title=$testName" \
                -F "close_old_findings=true" \
                -F 'deduplication_on_engagement=true' \
                -F 'create_finding_groups_for_all_findings=false' \
                -F "environment=$environment" \
                -F "api_scan_configuration=$sonarApiScan" \
                -F "branch_tag=$DEFECTDOJO_ENGAGEMENT"
        fi
    else
        ext=$(echo $report | cut -d "." -f 2)
        curl -X POST "$DEFECTDOJO_URL/api/v2/import-scan/" \
            -H "Authorization: Token $DEFECTDOJO_TOKEN" \
            -H "accept: application/json" \
            -H "Content-Type: multipart/form-data" \
            -F "engagement=$engagement" \
            -F "scan_type=$testName" \
            -F "test_title=$testName" \
            -F 'close_old_findings=true' \
            -F 'deduplication_on_engagement=true' \
            -F 'create_finding_groups_for_all_findings=false' \
            -F "environment=$environment" \
            -F "file=@$report;type=application/$ext" \
            -F "branch_tag=$DEFECTDOJO_ENGAGEMENT"
    fi
done

echo "::set-output name=response::'Success. No errors'"
