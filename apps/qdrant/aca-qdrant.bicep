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
      name: 'qdrant-share'
      properties: {
        enabledProtocols: 'SMB'
        accessTier: 'Premium'
      }
    }
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-10-01' = {
  name: 'aca-env'
  location: location
  dependsOn: [
    storageAccount
  ]
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
  }
  resource azureFilesStorage 'storages@2022-10-01' = {
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

resource qdrant 'Microsoft.App/containerApps@2022-10-01' = {
  name: 'qdrant-101'
  location: location
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 6334
        transport: 'http2'
        allowInsecure: true
      }
    }
    template: {
      containers: [
        {
          name: 'qdrant'
          image: 'docker.io/qdrant/qdrant:latest'
          env: [
            // assuming GRPC. Change targetPort (6333) and transport (http) for REST interface
            { name: 'QDRANT__SERVICE__GRPC_PORT', value: '6334'}
          ]
          volumeMounts: [
            {
              mountPath: '/qdrant/storage'
              volumeName: 'azurefilesmount'
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
          name: 'azurefilesmount'
          storageName: containerAppsEnvironment::azureFilesStorage.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
}
