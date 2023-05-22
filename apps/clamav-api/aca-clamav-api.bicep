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

resource clamd 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'clamd'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: false
        targetPort: 3310
        transport: 'tcp'
      }
    }
    template: {
      containers: [
        {
          name: 'clamd'
          image: 'docker.io/clamav/clamav:0.104'
          resources: {
            cpu: json('2.0')
            memory: '4.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource clamAVApi 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'clamav-api'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 3000
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'api'
          image: 'docker.io/benzino77/clamav-rest-api:latest'
          env: [
            {
              name: 'NODE_ENV'
              value: 'production'
            }
            {
              name: 'CLAMD_IP'
              value: clamd.name
            }
            {
              name: 'CLAMD_PORT'
              value: '3310'
            }
            {
              name: 'APP_FORM_KEY'
              value: 'FILES'
            }
            {
              name: 'APP_PORT'
              value: '3000'
            }
            {
              name: 'APP_MAX_FILE_SIZE'
              value: '26214400'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output clamAVApi string = 'https://${clamAVApi.properties.configuration.ingress.fqdn}'
output azClamAVApiLogs string = 'az containerapp logs show -n ${clamAVApi.name} -g ${resourceGroup().name} --revision ${clamAVApi.properties.latestRevisionName} --follow --tail 30'
output azClamAVApiExec string = 'az containerapp exec -n ${clamAVApi.name} -g ${resourceGroup().name} --revision ${clamAVApi.properties.latestRevisionName} --command /bin/bash'
output azShowClamAVApiRevision string = 'az containerapp revision show -n ${clamAVApi.name} -g ${resourceGroup().name} --revision ${clamAVApi.properties.latestRevisionName}'

output azClamdLogs string = 'az containerapp logs show -n ${clamd.name} -g ${resourceGroup().name} --revision ${clamd.properties.latestRevisionName} --follow --tail 30'
output azClamdExec string = 'az containerapp exec -n ${clamd.name} -g ${resourceGroup().name} --revision ${clamd.properties.latestRevisionName} --command /bin/bash'
output azShowClamdRevision string = 'az containerapp revision show -n ${clamd.name} -g ${resourceGroup().name} --revision ${clamd.properties.latestRevisionName}'
