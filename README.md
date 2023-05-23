# bicep-templates

```bash

export RESOURCE_GROUP="test-rg"
export LOCATION="East US"

az group create -n $RESOURCE_GROUP -l $LOCATION

az deployment group create -g $RESOURCE_GROUP \
    --query 'properties.outputs.*.value' \
    --template-file aca-app.bicep


[
  "https://shell.thankfulmushroom-a1dbb22c.eastus.azurecontainerapps.io",
  "az containerapp logs show -n webapp -g test-rg --revision webapp--xl1a6si --follow --tail 30",
  "az containerapp exec -n webapp -g test-rg --revision webapp--xl1a6si --command /bin/bash",
  "az containerapp revision show -n webapp -g test-rg --revision webapp--xl1a6si"
]
```
