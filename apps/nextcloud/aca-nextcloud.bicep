targetScope = 'resourceGroup'
param location string = resourceGroup().location

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: uniqueString(resourceGroup().name)
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'FileStorage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
  resource fileService 'fileServices@2022-09-01' = {
    name: 'default'
    resource fileShare 'shares@2022-09-01' = {
      name: 'apps-share'
      properties: {
        enabledProtocols: 'SMB'
        accessTier: 'Premium'
      }
    }
  }
}

resource appEnv 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: 'aca-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
  }
  resource azureFilesStorage 'storages@2022-11-01-preview' = {
    name: 'azurefilesstorage'
    properties: {
      azureFile: {
        accountName: storageAccount.name
        shareName: storageAccount::fileService::fileShare.name
        accessMode: 'ReadWrite'
        accountKey: storageAccount.listKeys().keys[0].value
      }
    }
  }
}

resource postgres 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'postgres'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      service: {
        type: 'postgres'
      }
    }
    template: {
      containers: [ { name: 'postgres', image: 'postgres' } ]
    }
  }
}

resource nextcloud 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'nextcloud'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
      }
    }
    template: {
      serviceBinds: [
        {
          serviceId: postgres.id
          name: 'postgres'
        }
      ]
      containers: [
        {
          name: 'nextcloud'
          image: 'docker.io/nextcloud:apache'
          command: [
            '/bin/sh'
          ]
          args: [
            '-c'
            '''
            export POSTGRES_HOST="$POSTGRES_HOST" && \
            export POSTGRES_PASSWORD="$POSTGRES_PASSWORD" && \
            export POSTGRES_DB="$POSTGRES_DATABASE" && \
            export POSTGRES_USER="$POSTGRES_USERNAME" && \
            /entrypoint.sh apache2-foreground
            '''
          ]
          volumeMounts: [
            {
              mountPath: '/var/www/html'
              volumeName: 'cifs-volume'
            }
          ]
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
      volumes: [
        {
          name: 'cifs-volume'
          storageName: appEnv::azureFilesStorage.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
}

output appUrl string = nextcloud.properties.configuration.ingress.fqdn
