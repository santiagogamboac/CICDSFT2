// Pipeline como código – Entrega 2 (Jenkins)
// Construye las imágenes de los dos servicios de la Entrega 1, levanta el
// docker compose y verifica que los contenedores se comunican por el nombre
// del servicio. Si cualquier paso falla, el build queda en rojo.
pipeline {
    agent any

    options {
        skipDefaultCheckout(true)          // el checkout se hace en su propia etapa
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    // Integración con GitHub: Jenkins revisa el repositorio cada 2 minutos y
    // lanza el pipeline solo cuando encuentra un commit nuevo (Poll SCM).
    triggers {
        pollSCM('H/2 * * * *')
    }

    environment {
        // Credencial guardada en Jenkins (usuario + contraseña de PostgreSQL).
        // Jenkins expone DB_CREDS_USR y DB_CREDS_PSW y las enmascara en la consola.
        DB_CREDS = credentials('notas-db-credentials')
        COMPOSE_PROJECT_NAME = 'notas-ci'
        APP_PUBLIC_PORT = '8081'           // 8080 ya lo usa Jenkins
        IMAGE_TAG = '1.0.0'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1 --pretty=format:"Commit: %h | %an | %s"'
            }
        }

        stage('Build') {
            steps {
                sh 'docker version --format "Docker cliente {{.Client.Version}} / servidor {{.Server.Version}}"'
                // El .env se genera con las credenciales de Jenkins; nunca está en el repositorio
                sh '''
                    printf 'POSTGRES_USER=%s\\nPOSTGRES_PASSWORD=%s\\nPOSTGRES_DB=notas_db\\nAPP_PUBLIC_PORT=%s\\n' \
                        "$DB_CREDS_USR" "$DB_CREDS_PSW" "$APP_PUBLIC_PORT" > .env
                    docker compose config --quiet
                '''
                script {
                    // Plugin Docker Pipeline: una imagen por servicio
                    def app = docker.build("notas-app:${env.IMAGE_TAG}", './app')
                    def db  = docker.build("notas-db:${env.IMAGE_TAG}", './db')
                    app.tag("build-${env.BUILD_NUMBER}")
                    db.tag("build-${env.BUILD_NUMBER}")
                }
                sh 'docker image ls --filter reference="notas-*"'
            }
        }

        stage('Test') {
            steps {
                // Parte de un estado limpio (sin contenedores ni volúmenes de builds anteriores)
                sh 'docker compose down -v --remove-orphans || true'
                // Levanta los dos contenedores y espera a que estén "healthy"
                sh 'docker compose up -d --wait --wait-timeout 120'
                sh 'docker compose ps'
                // Prueba de ida y vuelta app -> db por nombre de servicio
                sh 'sh tests/test_comunicacion.sh'
            }
        }
    }

    post {
        always {
            sh 'docker compose logs --no-color > compose-logs.txt 2>&1 || true'
            archiveArtifacts artifacts: 'compose-logs.txt', allowEmptyArchive: true
            sh 'docker compose down -v --remove-orphans || true'
            sh 'rm -f .env'
        }
        success {
            echo 'PIPELINE OK: imágenes construidas y comunicación app <-> db verificada.'
        }
        failure {
            echo 'PIPELINE FALLIDO: revisar la etapa en rojo y el archivo compose-logs.txt.'
        }
    }
}
