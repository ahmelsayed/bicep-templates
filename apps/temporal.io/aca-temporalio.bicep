param location string = resourceGroup().location
param temporalVersion string = '1.20.0'
param temporalUiVersion string = '2.10.3'

resource appEnv 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: 'aca-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
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
  }
}

resource temporal 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'temporal'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 7233
        transport: 'http2'
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
          name: 'temporal'
          image: 'docker.io/temporalio/auto-setup:${temporalVersion}'
          env: [
            {
              name: 'DB'
              value: 'postgresql'
            }
          ]
          command: [
            '/bin/sh'
          ]
          args: [
            '-c'
            '''
            DB_PORT="5432" \
            POSTGRES_USER="$POSTGRES_USERNAME" \
            POSTGRES_PWD="$POSTGRES_PASSWORD" \
            POSTGRES_SEEDS="$POSTGRES_HOST" \
            /etc/temporal/entrypoint.sh autosetup
            '''
          ]
        }
      ]
      scale: {
        maxReplicas: 1
        minReplicas: 1
      }
    }
  }
}

resource temporalAdminTools 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'temporal-admin-tools'
  location: location
  properties: {
    environmentId: appEnv.id
    template: {
      containers: [
        {
          name: 'temporal'
          image: 'docker.io/temporalio/admin-tools:${temporalVersion}'
          env: [
            {
              name: 'TEMPORAL_CLI_ADDRESS'
              value: '${temporal.name}:80'
            }
          ]
        }
      ]
      scale: {
        maxReplicas: 1
        minReplicas: 1
      }
    }
  }
}

resource temporalUi 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'temporal-ui'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'temporal'
          image: 'docker.io/temporalio/ui:${temporalUiVersion}'
          env: [
            {
              name: 'TEMPORAL_ADDRESS'
              value: '${temporal.name}:80'
            }
            {
              name: 'TEMPORAL_CORS_ORIGINS'
              value: 'http://localhost:3000'
            }
          ]
        }
      ]
      scale: {
        maxReplicas: 1
        minReplicas: 1
      }
    }
  }
}
