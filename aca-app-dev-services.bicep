targetScope = 'resourceGroup'
param location string = resourceGroup().location
param externalShell bool = false

resource appEnv 'Microsoft.App/managedEnvironments@2023-04-01-preview' = {
  name: 'aca-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
  }
}

resource postgres 'Microsoft.App/containerApps@2023-04-01-preview' = {
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

resource redis 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'redis'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      service: {
        type: 'redis'
      }
    }
  }
}

resource kafka 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'kafka'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      service: {
        type: 'kafka'
      }
    }
  }
}

resource shell 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'shell'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: externalShell
        targetPort: 8376
        transport: 'http'
      }
    }
    template: {
      serviceBinds: [
        {
          serviceId: postgres.id
          name: 'postgres'
        }
        {
          serviceId: redis.id
          name: 'redis'
        }
        {
          serviceId: kafka.id
          name: 'kafka'
        }
      ]
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

resource pgweb 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'pgweb'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8081
      }
    }
    template: {
      serviceBinds: [
        {
          serviceId: postgres.id
          name: 'postgres'
          customizedKeys: {
            PGWEB_DATABASE_URL: POSTGRES_URL
          }
        }
      ]
      containers: [
        {
          name: 'pgweb'
          image: 'docker.io/sosedoff/pgweb:latest'
        }
      ]
    }
  }
}

resource kafkaUi 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'kafka-ui'
  location: location
  properties: {
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
    }
    template: {
      serviceBinds: [
        {
          serviceId: kafka.id
          name: 'kafka'
          customizedKeys: {
            KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: KAFKA_BOOTSTRAP_SERVERS
            KAFKA_CLUSTERS_0_PROPERTIES_SASL_JAAS_CONFIG: KAFKA_PROPERTIES_SASL_JAAS_CONFIG
            KAFKA_CLUSTERS_0_PROPERTIES_SASL_MECHANISM: KAFKA_SASL_MECHANISM
            KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL: KAFKA_SECURITY_PROTOCOL
          }
        }
      ]
      containers: [
        {
          name: 'kafka-ui'
          image: 'docker.io/provectuslabs/kafka-ui:latest'
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
        }
      ]
    }
  }
}

output shellUrl string = 'https://${shell.properties.configuration.ingress.fqdn}'
output shellId string = shell.id
output shellLatestCreatedRevision string = shell.properties.latestRevisionName
output shellLatestCreatedRevisionId string = '${shell.id}/revisions/${shell.properties.latestRevisionName}'
output shellLatestReadyRevision string = shell.properties.latestReadyRevisionName
output shellLatestReadyRevisionId string = '${shell.id}/revisions/${shell.properties.latestReadyRevisionName}'
output azShellLogs string = 'az containerapp logs show -n ${shell.name} -g ${resourceGroup().name} --revision ${shell.properties.latestRevisionName} --follow --tail 30'
output azShellExec string = 'az containerapp exec -n ${shell.name} -g ${resourceGroup().name} --revision ${shell.properties.latestRevisionName} --command /bin/zsh'
output azShowShellRevision string = 'az containerapp revision show -n ${shell.name} -g ${resourceGroup().name} --revision ${shell.properties.latestRevisionName}'

output pgwebUrl string = 'https://${pgweb.properties.configuration.ingress.fqdn}'
output pgwebId string = pgweb.id
output pgwebLatestCreatedRevision string = pgweb.properties.latestRevisionName
output pgwebLatestCreatedRevisionId string = '${pgweb.id}/revisions/${pgweb.properties.latestRevisionName}'
output pgwebLatestReadyRevision string = pgweb.properties.latestReadyRevisionName
output pgwebLatestReadyRevisionId string = '${pgweb.id}/revisions/${pgweb.properties.latestReadyRevisionName}'
output azPgwebLogs string = 'az containerapp logs show -n ${pgweb.name} -g ${resourceGroup().name} --revision ${pgweb.properties.latestRevisionName} --follow --tail 30'
output azPgwebExec string = 'az containerapp exec -n ${pgweb.name} -g ${resourceGroup().name} --revision ${pgweb.properties.latestRevisionName} --command /bin/bash'
output azShowPgwebRevision string = 'az containerapp revision show -n ${pgweb.name} -g ${resourceGroup().name} --revision ${pgweb.properties.latestRevisionName}'

output kafkaUiUrl string = 'https://${kafkaUi.properties.configuration.ingress.fqdn}'
output kafkaUiLatestCreatedRevision string = kafkaUi.properties.latestRevisionName
output kafkaUiLatestCreatedRevisionId string = '${kafkaUi.id}/revisions/${kafkaUi.properties.latestRevisionName}'
output kafkaUiLatestReadyRevision string = kafkaUi.properties.latestReadyRevisionName
output kafkaUiLatestReadyRevisionId string = '${kafkaUi.id}/revisions/${kafkaUi.properties.latestReadyRevisionName}'
output azKafkaUiLogs string = 'az containerapp logs show -n ${kafkaUi.name} -g ${resourceGroup().name} --revision ${kafkaUi.properties.latestRevisionName} --follow --tail 30'
output azKafkaUiExec string = 'az containerapp exec -n ${kafkaUi.name} -g ${resourceGroup().name} --revision ${kafkaUi.properties.latestRevisionName} --command /bin/bash'
output azShowKafkaUiRevision string = 'az containerapp revision show -n ${kafkaUi.name} -g ${resourceGroup().name} --revision ${kafkaUi.properties.latestRevisionName}'
