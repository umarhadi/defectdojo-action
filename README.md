# DefectDojo Actions
This uploads reports to your DefectDojo. It allows to execute the following actions:
1. Check productType. It will not create it. You need to preconfigure it manually with necessary permissions.
2. Check and create product for setted productType if needed.
3. Check and create engagement inside product if needed.
4. Check and create environment.
5. Integrate SonarQube API and use it for importing the tests.
6. Get Github Vulnerability report.
7. Import reports/api scan

## Usage

See [action.yml](https://github.com/C4tWithShell/defectdojo-action/blob/master/action.yml)

### Upload Report

```
steps:
  - name: Clone code repository
    uses: actions/checkout@v4
  - name: DefectDojo
    id: defectdojo
    uses: C4tWithShell/defectdojo-action@1.0.5
    with:
      token: ${{ secrets.DEFECTOJO_TOKEN }}
      defectdojo_url: ${{ secrets.DEFECTOJO_URL }}
      product_type: example
      product: ${{ github.repository }}
      engagement: ${{ github.ref_name }}
      tools: "SonarQube API Import,Github Vulnerability Scan"
      sonar_projectKey: example:project
      github_token: ${{ secrets.GITHUB_TOKEN }}
      github_repository: ${{ github.repository }}
      environment: Dev
      reports: '{"Github Vulnerability Scan": "github.json"}'
  - name: Show response
    run: |
      set -e
      printf '%s\n' '${{ steps.defectdojo.outputs.response }}'
```

For `SonarQube API Import` don't forget to create a Tool config in your DefectDojo!