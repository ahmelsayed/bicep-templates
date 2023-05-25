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
        minReplicas: 0
        maxReplicas: 5
        rules: [
          {
            // target 10 requests per replica/instance
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
          {
            // scale to 1 during business hours (Mon-Fri 8am-6pm)
            custom: {
              type: 'cron'
              metadata: {
                timezone: 'America/Los_Angeles'
                start: '0 8 * * MON-FRI'
                end: '0 18 * * MON-FRI'
                desiredReplicas: '1'
              }
            }
          }
          {
            // target average CPU utilization of 80%
            custom: {
              type: 'cpu'
              metadata: {
                type: 'utilization'
                value: '80'
              }
            }
          }
          {
            // target average memory utilization of 70%
            custom: {
              type: 'memory'
              metadata: {
                type: 'utilization'
                value: '70'
              }
            }
          }
        ]
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
