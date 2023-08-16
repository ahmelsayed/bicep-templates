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

var nginxConf = loadTextContent('default.conf')
resource nginx 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'nginx'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      secrets: [
        {
          name: 'nginx-conf'
          value: nginxConf
        }
      ]
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'nginx'
          image: 'nginx:latest'
          volumeMounts: [
            {
              mountPath: '/etc/nginx/conf.d/'
              volumeName: 'nginx-conf'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: 'nginx-conf'
          storageType: 'Secret'
          secrets: [
            {
              secretRef: 'nginx-conf'
              path: 'default.conf'
            }
          ]
        }
      ]
    }
  }
}

resource appv1 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'appv1'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: false
        targetPort: 8080
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'main'
          image: 'docker.io/ahmelsayed/no:1'
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource appv2 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'appv2'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: false
        targetPort: 8080
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'main'
          image: 'docker.io/ahmelsayed/no:1'
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output appUrl string = 'https://${nginx.properties.configuration.ingress.fqdn}'
output appId string = nginx.id
output latestCreatedRevision string = nginx.properties.latestRevisionName
output latestCreatedRevisionId string = '${nginx.id}/revisions/${nginx.properties.latestRevisionName}'
output latestReadyRevision string = nginx.properties.latestReadyRevisionName
output latestReadyRevisionId string = '${nginx.id}/revisions/${nginx.properties.latestReadyRevisionName}'
output azAppLogs string = 'az containerapp logs show -n ${nginx.name} -g ${resourceGroup().name} --revision ${nginx.properties.latestRevisionName} --follow --tail 30'
output azAppExec string = 'az containerapp exec -n ${nginx.name} -g ${resourceGroup().name} --revision ${nginx.properties.latestRevisionName} --command /bin/bash'
output azShowRevision string = 'az containerapp revision show -n ${nginx.name} -g ${resourceGroup().name} --revision ${nginx.properties.latestRevisionName}'
