# HexaAlerts

> Status: a primeira versão está implementada. O projeto inclui domínio,
> webhook autenticado, processamento idempotente com Sidekiq, placar,
> assinaturas por torcedor, painel responsivo e Turbo Streams via Redis.

HexaAlerts é uma plataforma de notificações em tempo real para a Copa
do Mundo de 2026. A aplicação recebe eventos esportivos por webhook, processa os
dados em segundo plano e distribui alertas personalizados para torcedores via web.

O objetivo técnico do projeto é treinar uma arquitetura Rails moderna usando:

- Ruby on Rails como aplicação principal, API de entrada e camada de negócio.
- PostgreSQL como fonte de verdade para usuários, seleções, jogos, eventos e
  preferências.
- Sidekiq como sistema de tarefas em segundo plano, para processar eventos sem
  bloquear a requisição do webhook.
- Redis como backend das filas do Sidekiq e canal de transmissão em tempo real.
- Hotwire Turbo Streams para atualizar o navegador do usuário sem polling.
- Bun e Tailwind CSS para empacotamento de JavaScript e estilo.

## Visão geral

Fluxo principal de um gol:

```text
[API de Dados da Copa] -- webhook --> [Rails API Endpoint]
                                      |
                                      | enfileira job
                                      v
                                [Sidekiq Worker]
                                      |
                                      | atualiza estado
                                      v
                              [PostgreSQL Database]
                                      |
                                      | broadcast
                                      v
                          [Turbo Streams via Redis]
                                      |
                                      v
                            [Navegador do Torcedor]
```

O endpoint Rails deve responder rápido ao provedor de dados. Ele valida o
payload, registra uma entrada mínima, se necessária, e enfileira um job. O
Sidekiq normaliza o evento, atualiza o banco, identifica
assinaturas afetadas e publica a atualização em tempo real.

## Pré-requisitos

Instale antes de rodar o projeto:

- Ruby compatível com `.ruby-version`.
- PostgreSQL.
- Redis.
- Bun.
- Bundler.

Comandos úteis para conferir as versões:

```bash
ruby -v
```

Mostra a versão atual do Ruby. Use a versão definida em `.ruby-version` para
evitar incompatibilidades com Rails e gems nativas.

```bash
bundle -v
```

Confirme se o Bundler está instalado.

```bash
psql --version
```

Confirme se o cliente do PostgreSQL está disponível. O Rails usa PostgreSQL
como banco principal neste projeto.

```bash
redis-server --version
```

Confirme se o Redis está instalado. O Sidekiq depende dele para as filas de
jobs, e o Action Cable pode usá-lo para transmissões em tempo real.

```bash
bun --version
```

Confirme se o Bun está disponível para empacotar JavaScript.

## Criação do projeto

O projeto foi criado com:

```bash
rails new hexa_alerts --database=postgresql --javascript=bun --css=tailwind
```

Explicação:

- `rails new hexa_alerts` cria uma nova aplicação Rails.
- `--database=postgresql` configura Active Record para usar PostgreSQL.
- `--javascript=bun` configura Bun como ferramenta de build JavaScript.
- `--css=tailwind` instala o pipeline de CSS com Tailwind.

Entre na pasta do projeto:

```bash
cd hexa_alerts
```

## Instalação local

Instale as gems:

```bash
bundle install
```

O Bundler lê o `Gemfile`, baixa as dependências Ruby e grava as versões exatas
em `Gemfile.lock`.

Instale as dependências JavaScript:

```bash
bun install
```

O Bun instala os pacotes usados pelo build de JavaScript e Tailwind.

Crie o banco de dados:

```bash
bin/rails db:create
```

Esse comando cria os bancos `hexa_alerts_development` e `hexa_alerts_test` no
PostgreSQL, conforme `config/database.yml`.

Rode as migrações:

```bash
bin/rails db:migrate
```

Inicie o servidor de desenvolvimento:

```bash
bin/dev
```

`bin/dev` usa o `Procfile.dev` para subir Rails, build de CSS e build de
JavaScript juntos. Em desenvolvimento, acesse `http://localhost:3000`.

## Dependências de mensageria

Rails 8 vem preparado para usar adaptadores baseados em banco, como
`solid_queue` e `solid_cable`. Para este projeto, a proposta de arquitetura usa
Sidekiq e Redis porque o caso de uso exige fila rápida, concorrência simples de
operar e bom suporte operacional.

Adicione as gems:

```bash
bundle add sidekiq redis
```

Explicação:

- `sidekiq` executa jobs em segundo plano usando threads.
- `redis` fornece o cliente Ruby usado para conversar com o servidor Redis.

Configure o Active Job para usar Sidekiq:

```bash
bin/rails generate initializer sidekiq
```

Esse comando cria um arquivo em `config/initializers`. Nele, configure o Redis
do Sidekiq:

```ruby
# config/initializers/sidekiq.rb
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/2")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
```

Configure o adaptador de jobs no Rails:

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
```

Use variável de ambiente para apontar o Redis:

```bash
export REDIS_URL=redis://localhost:6379/2
```

Essa variável evita fixar credenciais ou hosts no código. Em produção, ela deve
apontar para o Redis gerenciado do ambiente.
Sem a variável, o Sidekiq usa o DB 2 local; o Action Cable usa o DB 1. Essa
separação evita consumir filas de outras aplicações que usem o DB 0.

Suba o Redis local:

```bash
redis-server
```

Esse comando inicia o servidor Redis. Mantenha esse processo aberto em um
terminal separado.

Suba o Sidekiq:

```bash
bundle exec sidekiq
```

Esse comando inicia os workers que consomem as filas. Se um webhook enfileirar
um job e o Sidekiq não estiver em execução, o job permanecerá no Redis.
O arquivo `config/sidekiq.yml` prioriza a fila `match_events` e também consome a
fila `default`.

## Modelagem inicial

Crie os principais modelos de domínio:

```bash
bin/rails generate model Team fifa_code:string name:string country:string group_name:string
```

Cria a tabela de seleções. `fifa_code` é o código curto usado por provedores,
como `BRA`, `ARG` ou `FRA`.

```bash
bin/rails generate model Match home_team:references away_team:references starts_at:datetime status:string external_id:string
```

Cria a tabela de jogos. `external_id` guarda o identificador do provedor de
dados para evitar duplicidade.

Depois ajuste o model gerado para deixar claro que os dois relacionamentos
apontam para `Team`:

```ruby
# app/models/match.rb
belongs_to :home_team, class_name: "Team"
belongs_to :away_team, class_name: "Team"
```

```bash
bin/rails generate model MatchEvent match:references team:references kind:string occurred_at:datetime payload:jsonb external_id:string
```

Cria a tabela de eventos do jogo. `kind` pode ser `goal`, `yellow_card`,
`red_card`, `var_review` ou outro tipo normalizado pelo sistema.

```bash
bin/rails generate model Fan email:string name:string
```

Cria a tabela de torcedores.

```bash
bin/rails generate model AlertSubscription fan:references team:references match:references event_kind:string active:boolean
```

Cria as preferências de alerta. Uma assinatura pode ser por seleção, por jogo e por
tipo de evento.

Depois de gerar os modelos:

```bash
bin/rails db:migrate
```

Aplica as migrações no banco.

Carregue os dados de demonstração (Brasil × Marrocos, um torcedor e uma
assinatura de gols):

```bash
bin/rails db:seed
```

Recomendações de implementação:

- Adicione índices únicos em `external_id` para evitar processar o mesmo evento
  duas vezes.
- Use `null: false` em campos obrigatórios.
- Use `jsonb` apenas para payload bruto ou dados pouco estáveis. O que for regra
  de negócio deve virar uma coluna normal.

## Endpoint de Webhook

Crie um controller para receber eventos externos:

```bash
bin/rails generate controller Api::V1::Webhooks::MatchEvents create
```

Esse comando cria um controller versionado. Versionar API desde cedo ajuda a
trocar contrato com provedores sem quebrar consumidores antigos.

Configure a rota:

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    namespace :webhooks do
      resources :match_events, only: :create
    end
  end
end
```

Contrato esperado do endpoint:

```http
POST /api/v1/webhooks/match_events
Content-Type: application/json
```

Exemplo de payload:

```json
{
  "event_id": "provider-evt-123",
  "match_id": "provider-match-456",
  "type": "goal",
  "team_code": "BRA",
  "occurred_at": "2026-06-18T19:22:10Z",
  "player": "Camisa 10"
}
```

Responsabilidades do controller:

- Validar assinatura/token do provedor.
- Validar se o payload tem os campos mínimos.
- Enfileirar um job.
- Responder `202 Accepted` rapidamente.

Exemplo de resposta:

```json
{ "status": "accepted" }
```

O token vem de `WEBHOOK_TOKEN` (em desenvolvimento e teste, o valor alternativo é
`dev-token`). O jogo e os times precisam existir antes do evento; o seed cria o
`match-001` usado no exemplo. Um payload com campos ausentes, timestamp inválido
ou tipo de evento desconhecido retorna `422`; um token inválido retorna `401`.

## Job de processamento

Gere o job:

```bash
bin/rails generate job ProcessMatchEvent
```

Esse comando cria uma classe em `app/jobs/process_match_event_job.rb`.

Responsabilidades do job:

- Encontrar ou criar o jogo pelo `external_id`.
- Encontrar o time pelo `fifa_code`.
- Garantir idempotência pelo `event_id`.
- Persistir o `MatchEvent`.
- Buscar assinaturas afetadas.
- Disparar Turbo Streams para os usuários conectados.

Enfileiramento esperado no controller:

```ruby
ProcessMatchEventJob.perform_later(params.to_unsafe_h)
```

Use `perform_later` para delegar ao Active Job. Como o adaptador será Sidekiq, o
Rails envia esse trabalho para o Redis.

## Tempo real com Turbo Streams

Turbo Streams permite atualizar partes da página sem escrever uma SPA completa.

Gere uma tela inicial de painel:

```bash
bin/rails generate controller Dashboard index
```

Configure a rota raiz:

```ruby
root "dashboard#index"
```

Na tela do painel, assine um stream:

```erb
<%= turbo_stream_from "match_alerts" %>
<div id="alerts"></div>
```

Quando um gol for processado, o job pode publicar:

```ruby
Turbo::StreamsChannel.broadcast_prepend_to(
  "match_alerts",
  target: "alerts",
  partial: "match_events/alert",
  locals: { match_event: match_event }
)
```

Explicação:

- `broadcast_prepend_to` envia uma atualização para todos os navegadores
  inscritos no stream.
- `target: "alerts"` indica o elemento HTML que será atualizado.
- `partial` renderiza o HTML do alerta no servidor.

Para produção com múltiplas instâncias, configure o Action Cable com Redis em
`config/cable.yml`.

## Testes

Rode a suíte:

```bash
bin/rails test
```

Executa os testes unitários de modelos, jobs e controladores.

Rode testes de sistema:

```bash
bin/rails test:system
```

Executa testes que simulam o navegador. Use para validar fluxos reais do
usuário, como receber um alerta no painel.

Testes importantes para este projeto:

- Webhook responde `202 Accepted` quando o payload é válido.
- Webhook rejeita um payload sem token válido.
- Job cria apenas um `MatchEvent` para o mesmo `external_id`.
- Job atualiza o placar correto.
- A transmissão é disparada para os assinantes corretos.

## Qualidade e segurança

Rode RuboCop:

```bash
bundle exec rubocop
```

Analisa estilo e problemas comuns em Ruby/Rails.

Rode Brakeman:

```bash
bundle exec brakeman
```

Procura vulnerabilidades comuns em aplicações Rails.

Rode Bundler Audit:

```bash
bundle exec bundler-audit check --update
```

Atualiza a base de vulnerabilidades conhecidas e verifica as gems do projeto.

## Operação local recomendada

Use quatro terminais durante o desenvolvimento:

Terminal 1:

```bash
bin/dev
```

Rails, JavaScript e Tailwind.

Terminal 2:

```bash
redis-server
```

Redis local.

Terminal 3:

```bash
bundle exec sidekiq
```

Workers em segundo plano.

Terminal 4:

```bash
bin/rails console
```

Console Rails para investigar dados, testar modelos e simular eventos.

## Simulando um Webhook

Depois que a rota e o controller existirem, simule um gol com `curl`:

```bash
curl -X POST http://localhost:3000/api/v1/webhooks/match_events \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Token: dev-token" \
  -d '{
    "event_id": "evt-001",
    "match_id": "match-001",
    "type": "goal",
    "team_code": "BRA",
    "occurred_at": "2026-06-18T19:22:10Z",
    "player": "Camisa 10"
  }'
```

Explicação:

- `-X POST` define o método HTTP.
- `-H "Content-Type: application/json"` informa que o corpo é JSON.
- `-H "X-Webhook-Token: dev-token"` simula a autenticação simples do provedor.
- `-d` envia o payload do evento.

O endpoint deve responder rapidamente, e o processamento deve aparecer no
Sidekiq.

## Roadmap técnico

Primeira versão:

- Receber webhooks de eventos de jogo.
- Persistir times, jogos e eventos.
- Processar gols em segundo plano.
- Mostrar alertas em tempo real no painel.
- Permitir assinatura simples por time.

Segunda versão:

- Autenticação de torcedores.
- Preferências por canal: web, e-mail, push ou WhatsApp.
- Painel administrativo de jogos e payloads recebidos.
- Retentativas e fila de mensagens mortas para payloads inválidos.
- Métricas de latência por etapa: webhook, fila, processamento e transmissão.

Terceira versão:

- Integração com um provedor oficial que ofereça SLA contratado.
- Multi-tenant para outros campeonatos.
- Relatórios analíticos por seleção, jogo e volume de alertas.
- Rate limiting por provedor.
- Observabilidade com logs estruturados, rastreamento e painéis.

## Decisões de arquitetura

- O webhook deve ser rápido. Nunca processe tudo dentro da requisição.
- Jobs devem ser idempotentes. O mesmo evento pode chegar mais de uma vez.
- O banco de dados é a fonte de verdade. Redis é fila/cache, não armazenamento
  definitivo.
- Payload bruto deve ser preservado para auditoria e reprocessamento.
- A transmissão em tempo real deve ser consequência do evento persistido, não o
  contrário.
- Regras de negócio devem ficar em serviços, modelos e jobs, não em controladores.


Siga esse fluxo com calma. A melhor arquitetura aqui não nasce da inclusão de
muitas peças, mas da garantia de que cada peça tenha uma responsabilidade clara.

## O que já está entregue

- [x] Sidekiq e Redis configurados por `REDIS_URL`.
- [x] Modelos com validações, associações, chaves estrangeiras e índices únicos.
- [x] Webhook com autenticação em comparação de tempo constante e validação do
  contrato.
- [x] Job idempotente, protegido contra concorrência e com atualização do
  placar.
- [x] Alertas personalizados e transmissão apenas aos torcedores afetados.
- [x] Painel com criação e remoção de assinaturas e atualização via Turbo
  Streams.
- [x] Jogos ao vivo priorizados e modal de acesso rápido ao acompanhamento em
  tempo real.
- [x] Testes de requisição, job, idempotência, transmissão, modelos e painel.
- [x] Sincronização das 48 seleções, calendário e resultados históricos via
  World Cup 2026 API.

## Integração World Cup 2026 API

O importador usa os endpoints públicos `https://worldcup26.ir/get/teams` e
`https://worldcup26.ir/get/games`, fornecidos pelo projeto de código aberto
[`rezarahiminia/worldcup2026`](https://github.com/rezarahiminia/worldcup2026).
Os dados são sincronizados de forma idempotente por `fifa_code` e pelo ID da
partida no provedor.

Execute manualmente:

```bash
bin/rails world_cup:sync
```

Ou enfileire a sincronização:

```ruby
SyncWorldCupDataJob.perform_later
```

Configure outro host compatível quando necessário:

```bash
export WORLD_CUP_API_URL=https://worldcup26.ir
```

Se a API estiver indisponível, o importador usa os dados instantâneos versionados
em `db/data/worldcup2026`. O conjunto de dados alternativo cadastra as 48
seleções e o calendário, mas nunca substitui placares locais mais novos por
resultados zerados. Os horários desse conjunto são fornecidos sem fuso explícito
e interpretados no fuso da aplicação.

Fonte oficial para conferência dos grupos e classificação:
[FIFA — Copa do Mundo 2026](https://www.fifa.com/pt/tournaments/mens/worldcup/canadamexicousa2026/standings).

### Provedor secundário: football-data.org

O HexaAlerts também aceita a API v4 do
[`football-data.org`](https://www.football-data.org/) como segunda fonte de
calendário, status e placares. Crie uma chave no serviço e configure:

```bash
export FOOTBALL_DATA_API_TOKEN=sua-chave
bin/rails football_data:sync
```

A integração consulta a competição `WC` na temporada `2026`, envia a chave no
cabeçalho `X-Auth-Token` e reconcilia partidas por equipes e horário. O ID do
football-data.org torna-se um identificador alternativo e, portanto, não cria
outro cartão para uma partida já importada. É necessário que o plano associado
à chave tenha acesso à Copa; o serviço retorna `403` quando a competição não
pertence à assinatura.

Também é possível enfileirar a atualização:

```ruby
SyncFootballDataJob.perform_later
```

Essa fonte não substitui os dados instantâneos avançados de chutes, posse e
probabilidades; ela complementa placar, status, data e horário.

### Estatísticas detalhadas: ESPN Scoreboard

Chutes, chutes a gol, posse, faltas, escanteios e cartões são sincronizados do
placar público da ESPN e mesclados na mesma partida pelos identificadores
externos alternativos:

```bash
bin/rails espn:sync
```

Para sincronizar outra data:

```bash
DATE=2026-06-21 bin/rails espn:sync
```

Ou em segundo plano:

```ruby
SyncEspnDataJob.perform_later
```

Ao iniciar o Sidekiq, o ciclo é ativado automaticamente. A frequência se adapta
ao estado do torneio: 30 segundos enquanto houver partida `live` e 5 minutos
quando não houver. Bloqueios no Redis impedem cadeias duplicadas após reinícios
ou acionamentos repetidos. Os intervalos podem ser ajustados:

```bash
export ESPN_LIVE_SYNC_INTERVAL=30
export ESPN_IDLE_SYNC_INTERVAL=300
```

A sincronização consulta o dia informado e o dia anterior para cobrir partidas
que atravessam a meia-noite em UTC. Após persistir os dados instantâneos,
publica uma substituição Turbo Stream para os navegadores que acompanham a
partida.
