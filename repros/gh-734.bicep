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
output appLogs string = 'az containerapp logs show -n ${app.name} -g ${resourceGroup().name} --revision ${app.properties.latestRevisionName} --follow --tail 30'
output appExec string = 'az containerapp exec -n ${app.name} -g ${resourceGroup().name} --revision ${app.properties.latestRevisionName} --command /bin/bash'
output showRevision string = 'az containerapp revision show -n ${app.name} -g ${resourceGroup().name} --revision ${app.properties.latestRevisionName}'

output slowUrl string = 'https://${slow.properties.configuration.ingress.fqdn}'
output slowLogs string = 'az containerapp logs show -n ${slow.name} -g ${resourceGroup().name} --revision ${slow.properties.latestRevisionName} --follow --tail 30'
output slowExec string = 'az containerapp exec -n ${slow.name} -g ${resourceGroup().name} --revision ${slow.properties.latestRevisionName} --command /bin/bash'
output showSlowRevision string = 'az containerapp revision show -n ${slow.name} -g ${resourceGroup().name} --revision ${slow.properties.latestRevisionName}'
