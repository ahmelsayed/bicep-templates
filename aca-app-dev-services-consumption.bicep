targetScope = 'resourceGroup'
param location string = resourceGroup().location

resource appEnv 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: 'aca-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
    zoneRedundant: false
    workloadProfiles: [
      {
        name: 'consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

resource postgres 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'postgres'
  location: location
  properties: {
    workloadProfileName: 'consumption'
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

resource redis 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'redis'
  location: location
  properties: {
    workloadProfileName: 'consumption'
    environmentId: appEnv.id
    configuration: {
      service: {
        type: 'redis'
      }
    }
    template: {
      containers: [ { name: 'redis', image: 'redis' } ]
    }
  }
}

resource kafka 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'kafka'
  location: location
  properties: {
    workloadProfileName: 'consumption'
    environmentId: appEnv.id
    configuration: {
      service: {
        type: 'kafka'
      }
    }
    template: {
      containers: [ { name: 'kafka', image: 'kafka' } ]
    }
  }
}

resource shell 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'shell'
  location: location
  properties: {
    workloadProfileName: 'consumption'
    environmentId: appEnv.id
    configuration: {
      ingress: {
        external: true
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

resource pgweb 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'pgweb'
  location: location
  properties: {
    workloadProfileName: 'consumption'
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
        }
      ]
      containers: [
        {
          name: 'pgweb'
          image: 'docker.io/sosedoff/pgweb:latest'
          command: [
            '/bin/sh'
          ]
          args: [
            '-c'
            'PGWEB_DATABASE_URL=$POSTGRES_URL /usr/bin/pgweb --bind=0.0.0.0 --listen=8081'
          ]
        }
      ]
    }
  }
}

resource kafkaUi 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'kafka-ui'
  location: location
  properties: {
    workloadProfileName: 'consumption'
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
        }
      ]
      containers: [
        {
          name: 'kafka-ui'
          image: 'docker.io/provectuslabs/kafka-ui:latest'
          command: [
            '/bin/sh'
          ]
          args: [
            '-c'
            '''export KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS="$KAFKA_BOOTSTRAP_SERVERS" && \
            export KAFKA_CLUSTERS_0_PROPERTIES_SASL_JAAS_CONFIG="$KAFKA_PROPERTIES_SASL_JAAS_CONFIG" && \
            export KAFKA_CLUSTERS_0_PROPERTIES_SASL_MECHANISM="$KAFKA_SASL_MECHANISM" && \
            export KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL="$KAFKA_SECURITY_PROTOCOL" && \
            java $JAVA_OPTS -jar kafka-ui-api.jar'''
          ]
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
        }
      ]
    }
  }
}

output shellUrl string = shell.properties.configuration.ingress.fqdn
output pgwebUrl string = pgweb.properties.configuration.ingress.fqdn
output kafkaUiUrl string = kafkaUi.properties.configuration.ingress.fqdn
