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
      name: 'mongodb-share-2'
      properties: {
        enabledProtocols: 'SMB'
        accessTier: 'Premium'
      }
    }
  }
}

resource appEnv 'Microsoft.App/managedEnvironments@2023-04-01-preview' = {
  name: 'aca-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
  }

  resource azureFilesStorage 'storages@2022-11-01-preview' = {
    name: 'azurefilesstorage-2'
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

resource mongodb 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'mongodb'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: false
        transport: 'tcp'
        targetPort: 27017
      }
    }
    template: {
      containers: [
        {
          name: 'mongodb'
          image: 'bitnami/mongodb:latest'
          env: [
            {
              name: 'MONGODB_ROOT_USER'
              value: 'root'
            }
            {
              name: 'MONGODB_ROOT_PASSWORD'
              value: 'password'
            }
          ]
          volumeMounts: [
            {
              mountPath: '/bitnami/mongodb'
              volumeName: 'mongo-volume'
            }
          ]
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          mountOptions: 'dir_mode=0777,file_mode=0777,uid=1001,gid=1001,mfsymlinks,nobrl'
          name: 'mongo-volume'
          storageName: appEnv::azureFilesStorage.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
}

resource mongodbExpress 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'mongodb-express'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: true
        transport: 'http'
        targetPort: 8081
      }
    }
    template: {
      containers: [
        {
          name: 'mongodb'
          image: 'mongo-express:latest'
          env: [
            {
              name: 'ME_CONFIG_MONGODB_URL'
              value: 'mongodb://root:password@mongodb:27017'
            }
            {
              name: 'ME_CONFIG_MONGODB_ADMINUSERNAME'
              value: 'root'
            }
            {
              name: 'ME_CONFIG_MONGODB_ADMINPASSWORD'
              value: 'password'
            }
          ]
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
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

output mongodbUrl string = 'https://${mongodb.properties.configuration.ingress.fqdn}'
output mongodbLatestCreatedRevision string = mongodb.properties.latestRevisionName
output mongodbLatestCreatedRevisionId string = '${mongodb.id}/revisions/${mongodb.properties.latestRevisionName}'
output mongodbLatestReadyRevision string = mongodb.properties.latestReadyRevisionName
output mongodbLatestReadyRevisionId string = '${mongodb.id}/revisions/${mongodb.properties.latestReadyRevisionName}'
output mongodbLogs string = 'az containerapp logs show -n ${mongodb.name} -g ${resourceGroup().name} --revision ${mongodb.properties.latestRevisionName} --follow --tail 30'
output mongodbExec string = 'az containerapp exec -n ${mongodb.name} -g ${resourceGroup().name} --revision ${mongodb.properties.latestRevisionName} --command /bin/bash'
output mongodbRevision string = 'az containerapp revision show -n ${mongodb.name} -g ${resourceGroup().name} --revision ${mongodb.properties.latestRevisionName}'


output mongodbExpressUrl string = 'https://${mongodbExpress.properties.configuration.ingress.fqdn}'
output mongodbExpressLatestCreatedRevision string = mongodbExpress.properties.latestRevisionName
output mongodbExpressLatestCreatedRevisionId string = '${mongodbExpress.id}/revisions/${mongodbExpress.properties.latestRevisionName}'
output mongodbExpressLatestReadyRevision string = mongodbExpress.properties.latestReadyRevisionName
output mongodbExpressLatestReadyRevisionId string = '${mongodbExpress.id}/revisions/${mongodbExpress.properties.latestReadyRevisionName}'
output mongodbExpressLogs string = 'az containerapp logs show -n ${mongodbExpress.name} -g ${resourceGroup().name} --revision ${mongodbExpress.properties.latestRevisionName} --follow --tail 30'
output mongodbExpressExec string = 'az containerapp exec -n ${mongodbExpress.name} -g ${resourceGroup().name} --revision ${mongodbExpress.properties.latestRevisionName} --command /bin/bash'
output mongodbExpressRevision string = 'az containerapp revision show -n ${mongodbExpress.name} -g ${resourceGroup().name} --revision ${mongodbExpress.properties.latestRevisionName}'
