terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }

   cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 3.0"
    }

  }
  required_version = ">= 0.13"
}

provider "cloudflare" {
  email   = var.cloudflare_id["email"]
  api_key = var.cloudflare_id["api_key"]
}

provider "scaleway" {
  zone            = var.scaleway_id["zone"]
  region          = var.scaleway_id["region"]
  access_key = var.scaleway_id["access_key"]
  secret_key = var.scaleway_id["secret_key"]
  project_id = var.scaleway_id["project_id"]
}


resource "scaleway_k8s_cluster" "epsicube" {
  name    = "epsicube"
  version = "1.23.0"
  cni     = "cilium"
}

resource "scaleway_k8s_pool" "epsi01" {
  cluster_id = scaleway_k8s_cluster.epsicube.id
  name       = "epsi01"
  node_type  = "DEV1-L"
  size       = var.kube_size
}

resource "null_resource" "kubeconfig" {
  depends_on = [scaleway_k8s_pool.epsi01] 
  triggers = {
    host                   = scaleway_k8s_cluster.epsicube.kubeconfig[0].host
    token                  = scaleway_k8s_cluster.epsicube.kubeconfig[0].token
    cluster_ca_certificate = scaleway_k8s_cluster.epsicube.kubeconfig[0].cluster_ca_certificate
  }
}

provider "kubernetes" {

  host  = null_resource.kubeconfig.triggers.host
  token = null_resource.kubeconfig.triggers.token
  cluster_ca_certificate = base64decode(
  null_resource.kubeconfig.triggers.cluster_ca_certificate
  )
}


resource "kubernetes_service_v1" "proxy-svc" {
  metadata {
    name = "proxy-svc"
  }
  spec {
    selector = {
      app = "proxy"
    }

    port {
      name = "entrypoint"
      protocol    = "TCP"
      port        = "25565"
      target_port = "25577"
    }

     port {
      name = "rcon"
      protocol    = "TCP"
      port        = "25575"
      target_port = "25575"
    }
    type = "LoadBalancer"
  }
}

resource "kubernetes_service_v1" "lobby-svc" {
  metadata {
    name = "lobby"
  }
  spec {
    selector = {
      app = "lobby"
    }
   
    port {
      name = "joueur"
      protocol    = "TCP"
      port        = "25585"
      target_port = "25565"
    }

    port {
      name = "rcon"
      protocol    = "TCP"
      port        = "25575"
      target_port = "25575"
    }

    port {
      name = "bedwars"
      protocol    = "TCP"
      port        = "2019"
      target_port = "2019"
    }

    type = "ClusterIP"
    cluster_ip = "None"
  }
} 

resource "kubernetes_service_v1" "bedwars-svc" {
  metadata {
    name = "bedwars"
  }
  spec {
    selector = {
      app = "bedwars"
    }
   
    port {
      name = "joueur"
      protocol    = "TCP"
      port        = "25585"
      target_port = "25565"
    }

    port {
      name = "rcon"
      protocol    = "TCP"
      port        = "25575"
      target_port = "25575"
    }


     port {
      name = "bedwars"
      protocol    = "TCP"
      port        = "2019"
      target_port = "2019"
    }

    type = "ClusterIP"
  }
} 

resource "kubernetes_endpoints_v1" "minecraft-db" {
  metadata {
    name = "minecraft-db"
  }

  subset {
    address {
      ip = scaleway_rdb_instance.main.endpoint_ip
    }

    port {
      name     = "mysql"
      port     = scaleway_rdb_instance.main.endpoint_port
      protocol = "TCP"
    }
  }

}


resource "kubernetes_service_v1" "minecraft-db" {
  metadata {
    name = "minecraft-db"
  }
  spec {
    port {
      name = "mysql"
      protocol    = "TCP"
      port        = "3306"
      target_port = scaleway_rdb_instance.main.endpoint_port
    }

    type = "ClusterIP"
  }
} 

resource "kubernetes_secret" "auth_s3" {
  metadata {
    name = "buckets3"
  }

  data = {
    username = var.bucket_id["id"]
    password = var.bucket_id["key"]
  }

  type = "kubernetes.io/basic-auth"
}

resource "kubernetes_secret" "docker-cfg" {
  metadata {
    name = "docker-cfg"
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "rg.fr-par.scw.cloud/proxy" = {
          auth = "${base64encode("nologin:a4f1704a-25cf-45d0-965a-4307cb29f2a5")}"
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"
}


resource "kubernetes_stateful_set_v1" "proxy" {
  metadata {
    name = "proxy"
    labels = {
      app = "proxy"
    }
  }

  spec {
    pod_management_policy  = "Parallel"
    replicas = 2
    service_name = "proxy"
    selector {
      match_labels = {
        app = "proxy"
      }
    }

    template {
      metadata {
        labels = {
          app = "proxy"
        }
      }

      spec {

 image_pull_secrets {
        name = "${kubernetes_secret.docker-cfg.metadata.0.name}"
      }


    container {
      image = "rg.fr-par.scw.cloud/proxy/proxy:latest"
      name  = "proxy-01"
      image_pull_policy = "Always"

       env {
        name = "ACCESSKEY"
        value = kubernetes_secret.auth_s3.data.username
      }

      env {
        name = "SECRETKEY"
        value = kubernetes_secret.auth_s3.data.password
      }


      env {
       name = "TYPE"
       value = "VELOCITY"
      }

      env {
       name = "DEBUG"
       value = "FALSE"
      }

      env {
       name = "ENABLE_RCON"
       value = "TRUE"
      }

      port {
        container_port = 25577
      }

    
      port {
        container_port = 25575
      }

     }
    }
    }
  }
}

resource "kubernetes_stateful_set_v1" "lobby" {
  metadata {
    name = "lobby"
    labels = {
      app = "lobby"
    }
  }

  spec {
    pod_management_policy  = "Parallel"
    replicas = 2
    service_name = "lobby"

    selector {
      match_labels = {
        app = "lobby"
      }
    }

    template {
      metadata {
        labels = {
          app = "lobby"
        }
      }

      spec {


 image_pull_secrets {
        name = "${kubernetes_secret.docker-cfg.metadata.0.name}"
      }

    container {
      image = "rg.fr-par.scw.cloud/proxy/lobby:latest"
      name  = "lobby"
      image_pull_policy = "Always"

      env {
        name = "ACCESSKEY"
        value = kubernetes_secret.auth_s3.data.username
      }

      env {
        name = "SECRETKEY"
        value = kubernetes_secret.auth_s3.data.password
      }


      env {
       name = "EULA"
       value = "TRUE"
      }

      env {
       name = "ONLINE_MODE"
       value = "TRUE"
      }

       env {
       name = "TYPE"
       value = "PAPER"
      }

      env {
       name = "ENABLE_RCON"
       value = "TRUE"
      }

      env {
       name = "RCON_PASSWORD"
       value = "testing"
      }

      env {
       name = "RCON_PORT"
       value = "25575"
      }
      env {
       name = "RCON_HOST"
       value = "proxy"
      }

      env {
       name = "VERSION"
       value = "1.16.5"
      }
      env {
       name = "PAPERBUILD"
       value = "794"
      }

      port {
        container_port = 25565
      }

       port {
        container_port = 25575
      }

      port {
        container_port = 2019
      }

     }
    }
   }
  }
 }

resource "scaleway_rdb_instance" "main" {
  name           = "minecraft-bdd"
  node_type      = "db-dev-m"
  engine         = "MySQL-8"
  is_ha_cluster  = true
  disable_backup = true
  user_name      = var.mysql_id["username"]
  password       = var.mysql_id["password"]
}

resource "scaleway_rdb_database" "friends" {
  instance_id    = scaleway_rdb_instance.main.id
  name           = "friends"
}

resource "scaleway_rdb_database" "bedwars1058" {
  instance_id    = scaleway_rdb_instance.main.id
  name           = "bedwars1058"
}

resource "kubernetes_stateful_set_v1" "bedwars" {
  metadata {
    name = "bedwars"
    labels = {
      app = "bedwars"
    }
  }

  spec {
    pod_management_policy  = "Parallel"
    replicas = 3
    service_name = "bedwars"

    selector {
      match_labels = {
        app = "bedwars"
      }
    }

    template {
      metadata {
        labels = {
          app = "bedwars"
        }
      }

      spec {

 image_pull_secrets {
        name = "${kubernetes_secret.docker-cfg.metadata.0.name}"
      }

    container {
      image = "rg.fr-par.scw.cloud/proxy/bedwars:latest"
      name  = "bedwars"
      image_pull_policy = "Always"

     env {
        name = "ACCESSKEY"
        value = kubernetes_secret.auth_s3.data.username
      }

      env {
        name = "SECRETKEY"
        value = kubernetes_secret.auth_s3.data.password
      }


      env {
       name = "EULA"
       value = "TRUE"
      }

      env {
       name = "ONLINE_MODE"
       value = "TRUE"
      }

       env {
       name = "TYPE"
       value = "PAPER"
      }

      env {
       name = "ENABLE_RCON"
       value = "TRUE"
      }

      env {
       name = "RCON_PASSWORD"
       value = "testing"
      }

      env {
       name = "RCON_PORT"
       value = "25575"
      }
      env {
       name = "RCON_HOST"
       value = "proxy"
      }

      env {
       name = "VERSION"
       value = "1.16.5"
      }
      env {
       name = "PAPERBUILD"
       value = "794"
      }

      port {
        container_port = 25565
      }

        port {
        container_port = 2019
      }


       port {
        container_port = 25575
      }

     }
    }
   }
  }
 }

resource "cloudflare_record" "methaverse" {
  zone_id = var.cloudflare_id["zone_id"]
  name    = var.cloudflare_id["dns_name"]
  value   = kubernetes_service_v1.proxy-svc.status[0].load_balancer[0].ingress[0].ip
  type    = "A"
  ttl     = 60
  proxied = "false"
}


output "instance_ip_addr" {
  value = kubernetes_service_v1.proxy-svc.status[0].load_balancer[0].ingress[0].ip
}


