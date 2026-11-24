# Infrastructure Terraform

L'infrastructure de `beanstalk-nodejs-app` est décrite avec Terraform dans ce
répertoire. Elle crée un environnement complet et isolé par valeur de
`environment` : réseau, ALB, ECR, ECS Fargate, CodeDeploy, IAM et monitoring.

## Arborescence

```text
infra/
├── bootstrap/            # bucket de state S3 + provider OIDC GitHub
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── versions.tf
├── modules/app/          # module applicatif réutilisable
│   ├── alb.tf            # ALB, deux target groups, listener, logs
│   ├── codedeploy.tf     # application et deployment group blue/green
│   ├── ecr.tf            # dépôt immuable, scan, cycle de vie
│   ├── ecs.tf            # cluster, task definition, service, autoscaling
│   ├── iam.tf            # rôles ECS, CodeDeploy, GitHub Actions
│   ├── main.tf           # données et locals partagés
│   ├── monitoring.tf     # SNS, alarmes, dashboard
│   ├── network.tf        # VPC, subnets, NAT, routes, security groups
│   ├── outputs.tf
│   └── variables.tf
└── envs/
    ├── dev/
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── variables.tf
    │   ├── versions.tf
    │   └── dev.tfvars
    └── prod/
        └── ... (même structure, prod.tfvars)
```

## Prérequis

- Terraform `>= 1.10` (le code utilise le verrouillage natif S3
  `use_lockfile = true`).
- AWS CLI authentifié sur le compte `682227955413`, région `eu-north-1`.
- Profil local utilisé dans les exemples : `dev-admin`
  (`aws sso login --profile dev-admin`).
- `jq` pour les scripts d'exploitation.

## Bootstrap

Le bootstrap crée deux ressources account-wide :

- le bucket S3 `beanstalk-nodejs-app-tfstate-682227955413`, versionné, chiffré,
  avec accès public bloqué et un verrou de state natif ;
- le fournisseur OIDC `token.actions.githubusercontent.com`.

```bash
cd infra/bootstrap
terraform init
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
```

Le state du bootstrap est **local** (`infra/bootstrap/terraform.tfstate`). Il
n'est pas versionné. Sauvegarder ce fichier après l'application.

Le nom du bucket est dérivé du compte AWS. Si le nom est déjà pris, passer
`-var state_bucket_name=<nom>` et reporter ce nom dans les backends des
environnements.

## Environnements

Les environnements `dev` et `prod` utilisent le même module avec des paramètres
différents et deux clés de state distinctes :

| | `dev` | `prod` |
| --- | --- | --- |
| State S3 | `envs/dev/terraform.tfstate` | `envs/prod/terraform.tfstate` |
| Tâches | 1 à 2 | 2 à 6 |
| CodeDeploy | `ECSAllAtOnce` | `ECSCanary10Percent5Minutes` |
| Rétention blue | 0 minute | 15 minutes |
| Logs | 30 jours | 90 jours |
| Protection ALB | non | oui |
| Suppression ECR avec images | autorisée | refusée |

Les backends S3 sont écrits en dur dans `infra/envs/<env>/versions.tf` :

```hcl
backend "s3" {
  bucket       = "beanstalk-nodejs-app-tfstate-682227955413"
  key          = "envs/dev/terraform.tfstate"
  region       = "eu-north-1"
  encrypt      = true
  use_lockfile = true
}
```

Si le compte ou le bucket change, mettre à jour les deux fichiers `versions.tf`.

## Commandes courantes

```bash
cd infra/envs/dev

terraform init
terraform fmt -check -recursive ../..
terraform validate

terraform plan -var-file=dev.tfvars -out=dev.tfplan
terraform apply dev.tfplan

terraform output
terraform state list
```

Pour `prod`, remplacer `dev` par `prod` et `dev.tfvars` par `prod.tfvars`.

La CI exécute les mêmes contrôles avec Terraform `1.15.5`. En local, une version
plus récente conforme à `required_version` fonctionne.

## Verrouillage du state

Le backend S3 utilise `use_lockfile = true` : Terraform écrit un objet de verrou
à côté du state, sans table DynamoDB. En cas de verrou orphelin après un arrêt
brutal :

```bash
terraform force-unlock <lock-id>
```

Vérifier qu'aucun autre processus ne travaille sur le même state avant de forcer
le déverrouillage.

## Variables du module

Les variables sont définies dans `infra/modules/app/variables.tf`.

| Variable | Rôle | Défaut |
| --- | --- | --- |
| `app_name` | préfixe de toutes les ressources | requis |
| `environment` | `dev` ou `prod` | requis |
| `state_bucket_name` | bucket de state, pour cadrer le rôle Terraform | requis |
| `vpc_cidr` | CIDR du VPC | `10.0.0.0/16` |
| `container_port` | port du conteneur | `8080` |
| `task_cpu` / `task_memory` | dimensionnement Fargate | `256` / `512` |
| `desired_count` | tâches au premier apply | `1` |
| `min_count` / `max_count` | bornes de l'autoscaling | `1` / `2` |
| `image_tag` | image de bootstrap avant le premier déploiement | `bootstrap` |
| `log_retention_days` | rétention CloudWatch Logs | `30` |
| `deployment_config_name` | configuration CodeDeploy ECS | `ECSAllAtOnce` |
| `blue_termination_wait_minutes` | délai avant suppression de l'ancien task set | `0` |
| `enable_deletion_protection` | protection de l'ALB | `false` |
| `ecr_force_delete` | suppression de l'ECR avec images | `false` |
| `alarm_emails` | abonnements email SNS | `[]` |
| `alarm_5xx_threshold` | seuil 5xx par minute | `5` |
| `alarm_latency_p95_seconds` | seuil p95 | `1` |
| `github_oidc_provider_arn` | provider OIDC créé par le bootstrap | requis |
| `github_subject_claims` | sujets OIDC autorisés | requis |
| `tags` | tags supplémentaires | `{}` |

Les fichiers `dev.tfvars` et `prod.tfvars` ne contiennent que `aws_region` et
`alarm_emails`. Les paramètres propres à l'environnement sont dans
`infra/envs/<env>/main.tf`.

## Sorties

Chaque environnement expose les sorties utilisées par
`scripts/setup-github-env.sh` :

- `aws_region`, `alb_name`, `alb_dns_name` ;
- `ecr_repository_name`, `ecs_cluster_name`, `ecs_service_name` ;
- `task_definition_family`, `codedeploy_application`,
  `codedeploy_deployment_group` ;
- `github_app_role_arn`, `github_terraform_role_arn` ;
- `container_name`, `container_port`.

Exemple :

```bash
terraform output -raw alb_dns_name
```

## IAM

Chaque environnement crée :

- `beanstalk-nodejs-app-<env>-ecs-execution` : récupération de l'image et
  écriture des logs ;
- `beanstalk-nodejs-app-<env>-ecs-task` : rôle applicatif, volontairement vide ;
- `beanstalk-nodejs-app-<env>-codedeploy` : rôle de service CodeDeploy ;
- `beanstalk-nodejs-app-<env>-gha-app` : rôle GitHub Actions de déploiement ;
- `beanstalk-nodejs-app-<env>-gha-terraform` : rôle GitHub Actions Terraform.

Le rôle Terraform peut gérer les ressources régionales nécessaires, le state de
son environnement et les rôles IAM préfixés par
`beanstalk-nodejs-app-<env>-`. Il ne peut pas modifier les rôles de l'autre
environnement.

Le rôle applicatif ne peut transmettre que les rôles d'exécution et de tâche à
`ecs-tasks.amazonaws.com`.

## CodeDeploy et ECS

- Le service ECS est créé avec `deployment_controller = CODE_DEPLOY`.
- Le listener HTTP de l'ALB pointe initialement vers le target group `blue`.
- CodeDeploy utilise la paire `blue`/`green` et bascule le listener pendant le
  déploiement.
- Terraform ignore `task_definition`, `desired_count` et `load_balancer` sur le
  service : CodeDeploy et l'autoscaling en sont propriétaires après le premier
  apply.
- La task definition initiale utilise l'image `:<image_tag>`, par défaut
  `bootstrap`. Elle permet de créer le service avant le premier passage de la
  CI. Tant que ce premier déploiement n'a pas eu lieu, les tâches peuvent rester
  unhealthy car l'image `:bootstrap` n'existe pas. C'est attendu et cela
  n'empêche pas le premier déploiement CodeDeploy.
- Le premier déploiement enregistre une révision avec l'image réelle par digest.
- Le deployment group attend jusqu'à 60 minutes que le task set de remplacement
  soit prêt. Au-delà, le déploiement est arrêté et annulé automatiquement. Un
  échec ou une alarme déclenche également le rollback.

## Monitoring

Chaque environnement crée :

- un sujet SNS `<app>-<env>-alarms` ;
- cinq alarmes : 5xx ALB, 5xx cible, latence p95, unhealthy blue, unhealthy
  green ;
- une alarme CPU sur le service ECS ;
- un dashboard `<app>-<env>-overview`.

Les cinq alarmes ALB/target groups sont branchées au deployment group CodeDeploy.
Pour recevoir les notifications, renseigner `alarm_emails` puis appliquer :

```hcl
alarm_emails = ["ops@example.com"]
```

L'abonnement doit être confirmé par email avant de recevoir les notifications.

## Destruction

### `dev`

```bash
cd infra/envs/dev
terraform destroy -var-file=dev.tfvars
```

`ecr_force_delete = true` pour `dev`, le dépôt ECR peut donc être supprimé avec
ses images. La suppression du service ECS et du deployment group peut prendre
plusieurs minutes.

### `prod`

La protection de l'ALB et du dépôt ECR empêche une destruction directe. Pour
détruire volontairement `prod` :

1. Dans `infra/envs/prod/main.tf`, passer temporairement
   `enable_deletion_protection = false` et, si les images doivent être perdues,
   `ecr_force_delete = true`.
2. Appliquer la configuration pour mettre à jour les ressources :

   ```bash
   terraform apply -var-file=prod.tfvars
   ```

3. Détruire :

   ```bash
   terraform destroy -var-file=prod.tfvars
   ```

4. Remettre les valeurs de production si l'environnement est recréé.

Ne pas détruire `infra/bootstrap` sans avoir supprimé les environnements : le
bucket contient leur state. La suppression d'un bucket versionné exige de
supprimer toutes les versions des objets.

## Dépannage

| Symptôme | Action |
| --- | --- |
| `Error: Failed to get existing workspaces` | vérifier les credentials AWS et le nom du bucket dans `versions.tf` |
| `Error acquiring the state lock` | vérifier les jobs en cours, puis `terraform force-unlock` |
| `BucketAlreadyExists` au bootstrap | changer `state_bucket_name` et reporter le nom dans les backends |
| `DeleteConflict` sur l'ALB | désactiver `enable_deletion_protection` et appliquer avant la destruction |
| `RepositoryNotEmptyException` | vider l'ECR ou passer `ecr_force_delete = true` |
| `InvalidParameterException` sur CodeDeploy | vérifier que les deux target groups existent et que le listener pointe vers `blue` |
| Les tâches ne démarrent pas | vérifier les subnets privés, le NAT gateway, le rôle d'exécution et les logs CloudWatch |

## Coûts

Les principaux postes sont le NAT gateway, l'ALB, les tâches Fargate, le stockage
ECR et les logs CloudWatch. `dev` et `prod` sont deux stacks distinctes : détruire
`dev` lorsqu'il n'est pas utilisé réduit la facture, au prix d'un recréation
complète et d'un nouveau premier déploiement.
