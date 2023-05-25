targetScope = 'resourceGroup'
param location string = resourceGroup().location

resource appEnv 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: 'aca-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
  }
}

resource app 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'webapp'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      activeRevisionsMode: 'Multiple'
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

resource slow 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'slow-chuncked'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      activeRevisionsMode: 'Multiple'
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'main'
          image: 'docker.io/ahmelsayed/slow-chunk'
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

output slowUrl string = 'https://${slow.properties.configuration.ingress.fqdn}'
output azSlowLogs string = 'az containerapp logs show -n ${slow.name} -g ${resourceGroup().name} --revision ${slow.properties.latestRevisionName} --follow --tail 30'
output azSlowExec string = 'az containerapp exec -n ${slow.name} -g ${resourceGroup().name} --revision ${slow.properties.latestRevisionName} --command /bin/bash'
output azShowSlowRevision string = 'az containerapp revision show -n ${slow.name} -g ${resourceGroup().name} --revision ${slow.properties.latestRevisionName}'
