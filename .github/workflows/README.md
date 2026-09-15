# Configuração dos workflows

Os workflows publicam imagens no ECR somente em `push` na branch `main`.
Em Pull Requests eles compilam, testam, analisam e escaneiam a imagem, mas não
recebem credenciais AWS e não publicam artefatos.

Crie o secret de repositório `AWS_ROLE_TO_ASSUME` com o ARN de uma role IAM
configurada para OIDC do GitHub Actions. Essa role deve ter, no mínimo,
permissões para autenticar e enviar imagens aos cinco repositórios ECR:
`auth-service`, `flag-service`, `targeting-service`, `evaluation-service` e
`analytics-service`.

O trust policy da role deve permitir `sts:AssumeRoleWithWebIdentity` apenas
para `repo:<organizacao>/<repositorio>:ref:refs/heads/main` e usar a audience
`sts.amazonaws.com`.
