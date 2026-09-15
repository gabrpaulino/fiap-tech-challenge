# Configuração dos workflows

Os workflows publicam imagens no ECR somente em `push` na branch `main`.
Em Pull Requests eles compilam, testam, analisam e escaneiam a imagem, mas não
recebem credenciais AWS e não publicam artefatos.

Crie os secrets do repositório:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` (opcional, para credenciais temporárias)
- `AWS_REGION`

Essas credenciais devem ter permissões para autenticar e enviar imagens aos cinco
repositórios ECR: `auth-service`, `flag-service`, `targeting-service`,
`evaluation-service` e `analytics-service`.

Se no futuro você decidir migrar para OIDC, pode usar `AWS_ROLE_TO_ASSUME` em
conjunto com `aws-actions/configure-aws-credentials`, mas o setup atual do projeto
é baseado em access keys.
