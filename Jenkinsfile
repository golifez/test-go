pipeline {
  agent {
    kubernetes {
      defaultContainer 'golang'
      yaml """
apiVersion: v1
kind: Pod
spec:
  volumes:
    # 1. Jenkins 工作区
    - name: workspace-volume
      emptyDir: {}

    # 2. Docker Daemon 存储
    - name: docker-graph-storage
      emptyDir: {}
  containers:
    - name: golang
      image: golang:1.23-alpine
      command: ['cat']
      tty: true
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent    # ← Jenkins 默认 WORKSPACE 根目录
        - name: docker-graph-storage
          mountPath: /var/lib/docker

    - name: dind
      image: docker:24-dind
      securityContext:
        privileged: true
      env:
        - name: DOCKER_TLS_CERTDIR
          value: ""
      command: ['dockerd-entrypoint.sh']
      args: ['--host=tcp://0.0.0.0:2375']
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent
        - name: docker-graph-storage
          mountPath: /var/lib/docker

    - name: docker
      image: docker:24-cli
      command: ['cat']
      tty: true
      volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent
        - name: docker-graph-storage
          mountPath: /var/lib/docker
"""
    }
  }

  environment {
    // ECR 相关配置
    ECR_REGISTRY       = '357819234932.dkr.ecr.ap-east-1.amazonaws.com'
    ECR_REPO           = 'golang/test'
    AWS_DEFAULT_REGION = 'ap-east-1'
  }

  stages {
    stage('Prepare Tools') {
      steps {
        container('golang') {
          sh 'apk update && apk add --no-cache git openssh-client'
        }
      }
    }

    stage('Checkout & Build') {
      steps {
        container('golang') {
          withCredentials([sshUserPrivateKey(
            credentialsId: '6c9329f1-04ea-4499-b919-acf713a2ee5a',
            keyFileVariable: 'SSH_KEY'
          )]) {
            sh '''
              mkdir -p ~/.ssh && chmod 700 ~/.ssh
              cp $SSH_KEY ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa
              ssh-keyscan github.com >> ~/.ssh/known_hosts

              git clone -b main git@github.com:golifez/test-go.git .
              go mod tidy
              go build -o app main.go
            '''
          }
        }
      }
    }

    stage('Docker Build') {
      steps {
        container('docker') {
          sh '''
            cd /home/jenkins/agent     # 进入挂载了代码的目录
            cd "$WORKSPACE"
            echo "查看文件"
            ls -al #查看文件
            export DOCKER_HOST=tcp://localhost:2375
            docker build -t $ECR_REGISTRY/$ECR_REPO:$BUILD_NUMBER .
          '''
        }
      }
    }
    stage('ECR Login & Push') {
      steps {
        container('docker') {
          withCredentials([usernamePassword(
            credentialsId: 'aws-ecr-creds',
            usernameVariable: 'AWS_ACCESS_KEY_ID',
            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
          )]) {
            sh '''
              cd "$WORKSPACE"
              export DOCKER_HOST=tcp://localhost:2375

              # 安装 python3 和 pip
              apk add --no-cache python3 py3-pip

              # 创建并激活 一个 Python venv
              python3 -m venv /tmp/awscli-venv
              . /tmp/awscli-venv/bin/activate

              # 在 venv 里安装 awscli
              pip install --upgrade pip awscli

              # 登录 ECR 并推送镜像
              aws ecr get-login-password --region $AWS_DEFAULT_REGION \
                | docker login --username AWS --password-stdin $ECR_REGISTRY

              docker push $ECR_REGISTRY/$ECR_REPO:$BUILD_NUMBER
              docker tag $ECR_REGISTRY/$ECR_REPO:$BUILD_NUMBER \
                        $ECR_REGISTRY/$ECR_REPO:latest
              docker push $ECR_REGISTRY/$ECR_REPO:latest
            '''
          }
        }
      }
    }



    stage('Success') {
      steps {
        echo "✅ Pushed: $ECR_REGISTRY/$ECR_REPO:$BUILD_NUMBER and :latest"
      }
    }
  }
}