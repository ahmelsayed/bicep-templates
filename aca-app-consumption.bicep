targetScope = 'resourceGroup'
param location string = resourceGroup().location

resource appEnv 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: 'aca-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
    workloadProfiles: [
      {
        name: 'consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

resource app 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'webapp'
  location: location
  properties: {
    workloadProfileName: 'consumption'
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8376
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'cloudshell'
          image: 'docker.io/ahmelsayed/cloudshell:latest'
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output appUrl string = 'https://${app.properties.configuration.ingress.fqdn}'
output appId string = app.id
output latestCreatedRevision string = app.properties.latestRevisionName
output latestCreatedRevisionId string = '${app.id}/revisions/${app.properties.latestRevisionName}'
output latestReadyRevision string = app.properties.latestReadyRevisionName
output latestReadyRevisionId string = '${app.id}/revisions/${app.properties.latestReadyRevisionName}'
output azAppLogs string = 'az containerapp logs show -n ${app.name} -g ${resourceGroup().name} --revision ${app.properties.latestRevisionName} --follow --tail 30'
output azAppExec string = 'az containerapp exec -n ${app.name} -g ${resourceGroup().name} --revision ${app.properties.latestRevisionName} --command /bin/bash'
output azShowRevision string = 'az containerapp revision show -n ${app.name} -g ${resourceGroup().name} --revision ${app.properties.latestRevisionName}'
