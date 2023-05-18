param location string = resourceGroup().location

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: uniqueString(resourceGroup().name)
  location: location
}
resource azureMonitorReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '43d0d8ad-25c7-4714-9337-8ba259a9fe05' // Azure Monitor Reader Role
}
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().name, azureMonitorReaderRole.name, uniqueString(resourceGroup().name))
  properties: {
    principalId: identity.properties.principalId
    roleDefinitionId: azureMonitorReaderRole.id
    principalType: 'ServicePrincipal'
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-10-01' = {
  name: 'aca-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
  }
}

var grafanaName = 'grafana'
var azureMonitorYaml = loadTextContent('grafana-files/provisioning/datasources/azuremonitor.yml')
var dashboardsYaml = loadTextContent('grafana-files/provisioning/dashboards/dashboards.yml')
var grafanaIni = loadTextContent('grafana-files/grafana.ini')

/// default ACA dashboards ///
// https://grafana.com/grafana/dashboards/16592-azure-container-apps-container-app-view/
var acaAppDashboardJson = loadTextContent('grafana-files/dashboards/aca-app-dashboard.json')
// https://grafana.com/grafana/dashboards/16591-azure-container-apps-aggregate-view/
var acaEnvDashboardJson = loadTextContent('grafana-files/dashboards/aca-env-dashboard.json')

resource grafana 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: grafanaName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      secrets: [
        { name: 'grafana-ini', value: replace(grafanaIni, '\${managedIdentityClientId}', identity.properties.clientId) }
        { name: 'dashboard-yml', value: dashboardsYaml }
        { name: 'azuremonitor-yml', value: azureMonitorYaml }
        { name: 'aca-app-dashboard-json', value: acaAppDashboardJson }
        { name: 'aca-env-dashboard-json', value: acaEnvDashboardJson }
      ]
      ingress: {
        external: true
        targetPort: 3000
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'grafana'
          image: 'docker.io/grafana/grafana:latest'
          volumeMounts: [
            {
              mountPath: '/etc/grafana'
              volumeName: 'gf-config'
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
          name: 'gf-config'
          storageType: 'Secret'
          secrets: [
            { secretRef: 'grafana-ini', path: 'grafana.ini' }
            { secretRef: 'dashboard-yml', path: 'provisioning/dashboards/dashboard.yml' }
            { secretRef: 'azuremonitor-yml', path: 'provisioning/datasources/azuremonitor.yml' }
            { secretRef: 'aca-app-dashboard-json', path: 'dashboards/aca-app-dashboard.json' }
            { secretRef: 'aca-env-dashboard-json', path: 'dashboards/aca-env-dashboard.json' }
          ]
        }
      ]
    }
  }
}

resource nginx 'Microsoft.App/containerApps@2022-10-01' = {
  name: 'nginx'
  location: location
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'nginx'
          image: 'docker.io/nginx:latest'
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

output grafanaUrl string = 'https://${grafana.properties.configuration.ingress.fqdn}'
output nginxUrl string = 'https://${nginx.properties.configuration.ingress.fqdn}'
