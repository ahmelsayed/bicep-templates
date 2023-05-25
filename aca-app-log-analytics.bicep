targetScope = 'resourceGroup'
param location string = resourceGroup().location


resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: 'log-analytics'
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource appEnv 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: 'aca-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource app 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'webapp'
  location: location
  properties: {
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
