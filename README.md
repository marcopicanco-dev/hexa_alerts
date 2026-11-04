<p align="center">
  <img src="docs/images/hexa-alerts-modernista.png" width="1200" alt="HexaAlerts — do primeiro lance ao apito final. Arte modernista com uma bola de futebol dentro de um hexágono e sinais de notificação, em marfim, grafite e terracota.">
</p>

# HexaAlerts ⚽

**Do primeiro lance ao apito final: uma aplicação Rails para acompanhar a Copa do Mundo de 2026.**

Projeto de portfólio que combina integração com APIs esportivas, processamento em
segundo plano e atualizações no navegador com Hotwire. Com a competição encerrada,
o painel funciona como um acervo navegável: resultados das 104 partidas, as cinco
melhores seleções e os cinco principais artilheiros.

![Painel do HexaAlerts com a competição encerrada, resultados e rankings finais](docs/screenshots/dashboard.png)

<p align="center">
  <strong>Ruby on Rails 8.1</strong> · PostgreSQL · Redis · Sidekiq · Hotwire · Bun · Tailwind CSS
</p>

**Finalidade acadêmica:** projeto de portfólio para estudar integrações HTTP, processamento assíncrono, consistência de dados e atualização de interfaces. Não é um serviço oficial dos organizadores ou dos provedores citados.

[Problema e solução](#problema-e-solução) · [Arquitetura](#arquitetura) · [Desafios técnicos](#desafios-técnicos) · [Executar localmente](#executar-localmente) · [Testes](#testes-e-qualidade)

## Problema e solução

Acompanhar uma competição com fontes diferentes exige lidar com identificadores incompatíveis, indisponibilidade de APIs e reenvio de eventos. Executar toda a sincronização dentro de uma requisição também faz o usuário aguardar operações externas.

O HexaAlerts normaliza e persiste os dados no PostgreSQL, processa atualizações com Sidekiq e entrega mudanças ao navegador com Hotwire. Arquivos versionados permitem demonstrar o sistema sem credenciais de uma API paga e servem como alternativa durante falhas de integração.

O projeto contempla dois cenários: processamento de eventos e acompanhamento durante o torneio, e consulta ao acervo depois do encerramento. O estado atual prioriza essa retrospectiva; não há partidas ao vivo em andamento apenas por iniciar a aplicação.

## Funcionalidades

- **Retrospectiva do torneio:** estado de competição encerrada, campeã em destaque
  e indicadores calculados a partir das partidas cadastradas.
- **Rankings finais:** top 5 seleções e top 5 artilheiros, com gols, assistências e
  links para as publicações oficiais da FIFA.
- **Atualizar aplicação:** um botão sincroniza seleções, calendário, placares,
  estatísticas e lances de todo o torneio em segundo plano. O painel informa o
  andamento e a última atualização, e se recarrega ao concluir via Turbo Streams.
- **Acervo de partidas:** filtros por grupos, mata-mata ou todos os jogos,
  incluindo final e disputa do terceiro lugar.
- **Detalhes de cada jogo:** placar, posse de bola, chutes, faltas, cartões,
  escanteios e lances registrados por jogador.
- **Alertas personalizados:** assinaturas por torcedor, seleção, partida e tipo
  de evento, com distribuição no navegador aos assinantes interessados. E-mail e push são propostas futuras.
- **Webhooks autenticados:** validação do contrato, comparação de token em tempo
  constante e processamento idempotente com Sidekiq.
- **Demonstração reproduzível:** seeds com as 48 seleções e as 104 partidas, sem
  depender da disponibilidade das APIs nem de uma chave paga.
- **Interface responsiva:** navegação em desktop e celular, foco de teclado
  visível e respeito à preferência por movimento reduzido.

## Arquitetura

```mermaid
flowchart TD
    A["Botão de atualização ou webhook"] --> B["Controllers"]
    B --> C["Jobs com Sidekiq e Redis"]
    C --> D["Serviços de importação e processamento"]
    E["APIs ou acervo local"] --> D
    D --> F[("PostgreSQL")]
    D --> G["Broadcasts após persistência"]
    G --> H["Turbo Streams e Action Cable"]
    H --> I["Painel e alertas no navegador"]
```

| Camada | Responsabilidade |
| --- | --- |
| Controllers | Receber requisições, validar entradas e iniciar operações. |
| Models | Associações, validações e integridade do domínio. |
| Services | Clientes HTTP, normalização, importação e reconciliação entre provedores. |
| Jobs | Processar eventos e executar sincronizações fora da requisição web. |
| PostgreSQL | Fonte de verdade, índices únicos e histórico de sincronizações. |
| Redis | Filas do Sidekiq e distribuição das mensagens do Action Cable. |
| Hotwire | Turbo Streams para atualizações e Stimulus para interações locais. |

A sincronização completa registra seu estado em `CompetitionSync`: na fila,
em execução, concluída ou falhou. Os detalhes indicam quantas partidas foram
importadas e se os dados vieram da API ou da cópia local. Uma falha mantém os
dados persistidos disponíveis e libera uma nova tentativa pelo botão.

### Tecnologias e decisões

| Tecnologia | Papel e decisão | Compromisso |
| --- | --- | --- |
| Ruby 4.0.5 e Rails 8.1 | Integrar domínio, endpoints, persistência e views na mesma aplicação. | A execução depende de um ambiente Ruby compatível. |
| PostgreSQL | Persistir partidas, referências externas, eventos, assinaturas e sincronizações; impor restrições de unicidade. | Requer migrations e atenção aos limites das transações. |
| Sidekiq e Redis | Retirar sincronização e processamento da requisição web. | Exigem worker e Redis disponíveis, além de tratamento de falhas. |
| Turbo Streams e Action Cable | Atualizar o painel e distribuir alertas no navegador. | Dependem da conexão do cliente; transmissão não equivale a entrega durável. |
| Stimulus | Implementar interações locais no frontend. | Comportamentos permanecem associados às views Rails. |
| Bun e Tailwind CSS | Compilar JavaScript e CSS usados pelo Propshaft. | Os bundles precisam ser gerados em cada instalação. |
| Minitest e Selenium | Verificar regras, integrações simuladas e navegação. | Testes de navegador exigem Chrome. |

### Fluxos principais

1. **Evento:** o controller valida o token e o contrato, enfileira o job e responde ao provedor. O job localiza a partida, verifica duplicidade, grava o evento sob bloqueio e atualiza o estado. Depois da persistência, transmite as mudanças ao navegador.
2. **Atualização completa:** o botão cria uma sincronização, enfileira o trabalho e permite continuar navegando. Os serviços consultam os provedores ou o acervo local; a operação registra origem, resultado ou falha.
3. **Consulta:** páginas e filtros usam os dados persistidos. O seed permite preparar o acervo sem consultar as APIs.

## Desafios técnicos

1. **Receber eventos repetidos sem duplicar gols ou notificações.**
   Provedores podem reenviar o mesmo webhook. O identificador externo tem índice
   único, o job usa proteção contra concorrência e os testes verificam que o
   mesmo evento altera o placar uma única vez.

2. **Reconciliar a mesma partida em provedores diferentes.**
   Cada API usa identificadores próprios e pode informar horários diferentes.
   A importação combina equipes e uma janela de horário, mantém referências
   externas alternativas e reúne eventos e assinaturas na partida canônica.

3. **Manter a aplicação demonstrável quando uma API sai do ar.**
   Os clientes HTTP têm limites de tempo, tratam respostas inválidas e usam
   arquivos locais como alternativa. O seed carrega o torneio completo sem
   chamadas externas, e o painel identifica quando uma atualização usou a cópia local.

4. **Atualizar todo o torneio sem bloquear a navegação.**
   O botão enfileira um job no Sidekiq. O estado da operação fica no PostgreSQL,
   um índice único parcial impede atualizações simultâneas e o Turbo Streams
   atualiza o navegador ao término. Falhas ficam visíveis e permitem tentar novamente.

5. **Transformar um painel ao vivo em um acervo coerente após a final.**
   O painel passou a mostrar o encerramento, a campeã, os rankings finais e as
   fases eliminatórias. A sincronização consulta toda a temporada, importa
   partidas ausentes e interrompe o ciclo recorrente após o torneio. Probabilidades
   ao vivo não são exibidas em partidas encerradas.

6. **Evitar a regressão de dados ao usar um calendário alternativo.**
   A importação de arquivos locais preserva placares e estados já atualizados,
   mantém os dados detalhados de outros provedores e reaproveita os registros.
   Testes de importação cobrem idempotência e preservação dos resultados.

7. **Garantir que o frontend funcione em uma instalação nova.**
   JavaScript e CSS compilados não ficam no Git. O `bin/setup` gera os bundles
   exigidos pelo Propshaft, e o `bin/dev` acompanha as alterações com Bun e
   Tailwind. O processo de instalação e a geração das capturas estão documentados.

### Evidências no código

| Decisão | Implementação | Verificação disponível |
| --- | --- | --- |
| Processamento idempotente | [ProcessMatchEventJob](app/jobs/process_match_event_job.rb) | [Testes do job](test/jobs/process_match_event_job_test.rb) |
| Reconciliação de partidas | [MatchDeduplicator](app/services/match_deduplicator.rb) | [Testes de importação ESPN](test/services/espn/importer_test.rb) |
| Alternativa local quando um provedor falha | [WorldCup2026::Refresh](app/services/world_cup_2026/refresh.rb) | [Testes de atualização](test/services/world_cup_2026/refresh_test.rb) |
| Controle de sincronizações | [Controller](app/controllers/competition_syncs_controller.rb) e [job](app/jobs/refresh_competition_job.rb) | [Testes do controller](test/controllers/competition_syncs_controller_test.rb) |
| Distribuição por assinatura | [MatchEventBroadcaster](app/services/match_event_broadcaster.rb) | [Testes de assinaturas](test/models/alert_subscription_test.rb) |
| Navegação e atualização da interface | Views, Turbo Streams e Stimulus | [Testes de sistema](test/system/dashboard_test.rb) |

## Dados e integrações

### Acervo e rankings finais

O arquivo [`summary.json`](db/data/worldcup2026/summary.json) registra os rankings
finais conferidos em **17/10/2026**, com os links de origem:

- [FIFA — classificação final do torneio](https://www.fifa.com/en/articles/final-tournament-standings).
- [FIFA — artilharia e Chuteira de Ouro](https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/articles/adidas-golden-boot-race-top-scorer).

Os rankings são um registro histórico versionado. Não são inferidos de um
conjunto parcial de eventos e não são recalculados pelo botão de atualização.
A ordem da artilharia segue a publicação da FIFA, incluindo os desempates por
assistências e menor tempo em campo.

O acervo [`espn_matches.json`](db/data/worldcup2026/espn_matches.json) contém as
104 partidas, com data da captura e endereço da consulta de origem. O encerramento
da competição considera o calendário da edição, cuja final ocorreu em 19/07/2026.

### Provedores

| Fonte | Dados | Configuração |
| --- | --- | --- |
| World Cup 2026 API | Seleções e calendário inicial | `WORLD_CUP_API_URL`, opcional. |
| ESPN Scoreboard | Resultados, fases, estatísticas e lances | `ESPN_SCOREBOARD_URL`, opcional. |
| football-data.org v4 | Fonte complementar de calendário e placares | `FOOTBALL_DATA_API_TOKEN`, opcional. |
| Arquivos locais | Demonstração e alternativa quando as APIs falham | Versionados em `db/data/worldcup2026`. |

A atualização completa consulta a temporada inteira na ESPN com limite de 200
registros, suficiente para as 104 partidas. Se a ESPN estiver indisponível, o
sistema usa o acervo local e sinaliza essa origem no painel. A fonte secundária
é consultada quando sua chave está configurada; sua indisponibilidade não impede
a sincronização principal.

Comandos individuais continuam disponíveis:

```bash
bin/rails world_cup:sync
bin/rails espn:sync

# Opcional, com uma chave que tenha acesso à competição WC de 2026
FOOTBALL_DATA_API_TOKEN=sua-chave bin/rails football_data:sync
```

Durante o torneio, a sincronização recorrente da ESPN usa intervalos de 30
segundos com jogos ao vivo e cinco minutos sem jogos ao vivo. Depois do fim da
competição, o ciclo recorrente não é iniciado novamente; o acervo pode continuar
sendo atualizado manualmente.

### Webhook de eventos

```http
POST /api/v1/webhooks/match_events
Content-Type: application/json
X-Webhook-Token: dev-token
```

Exemplo para testar o fluxo de recebimento e processamento em segundo plano.
Use o identificador de uma partida cadastrada, disponível no console com
`Match.first.external_id`:

```bash
curl -X POST http://localhost:3000/api/v1/webhooks/match_events \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Token: dev-token" \
  -d '{
    "event_id": "demo-event-001",
    "match_id": "worldcup2026:1",
    "type": "goal",
    "team_code": "MEX",
    "occurred_at": "2026-06-11T19:22:10Z",
    "player": "Jogador de demonstração"
  }'
```

A simulação altera o placar local; rode a atualização completa para restaurar os
resultados históricos depois da demonstração. O endpoint responde `202` para um
payload válido, `401` para token inválido e `422` para dados fora do contrato.
Em desenvolvimento e teste, o token alternativo é `dev-token`. Em produção,
configure `WEBHOOK_TOKEN`.

## Executar localmente

### Pré-requisitos

- Ruby compatível com [`.ruby-version`](.ruby-version) e Bundler.
- PostgreSQL em execução, com permissão para criar os bancos locais.
- Redis em execução.
- Bun para instalar as dependências e compilar JavaScript e CSS.
- Google Chrome para gerar as capturas de tela; não é necessário para subir o servidor.

### Preparar e iniciar

```bash
# Instala dependências, compila assets e prepara o banco
bin/setup --skip-server

# Carrega as 48 seleções, 104 partidas e os lances do acervo local
bin/rails db:seed

# Em outro terminal, caso o Redis ainda não esteja em execução
redis-server

# Inicia Rails, JavaScript, CSS e Sidekiq
bin/dev
```

Acesse **http://localhost:3000**. Para usar outra porta:

```bash
PORT=3003 bin/dev
```

O botão **Atualizar aplicação** usa o worker Sidekiq iniciado pelo `bin/dev`.
Durante a sincronização, o botão fica indisponível e o banco impede que duas
atualizações sejam iniciadas ao mesmo tempo. Ao concluir, o painel é atualizado
sem exigir que o usuário recarregue a página.

Também é possível sincronizar diretamente pelo terminal, sem worker:

```bash
bin/rails competition:refresh
```

Os seeds usam somente arquivos versionados. Reexecutá-los reaproveita as seleções,
partidas e eventos existentes, sem apagar assinaturas de torcedores.

### Assets

Os arquivos compilados de `app/assets/builds` não são versionados. O `bin/setup`
e o `bin/dev` preparam o frontend. Se optar por iniciar apenas `bin/rails server`,
gere os assets antes:

```bash
bun install
bun run build
bun run build:css
bin/rails server
```

Isso evita o erro `The asset 'application.js' was not found in the load path`.

### Configuração e produção

| Variável | Finalidade | Quando configurar |
| --- | --- | --- |
| `DATABASE_URL` | Conexão principal ao PostgreSQL. | Quando a conexão não utilizar a configuração local padrão. |
| `REDIS_URL` | Conexão Redis usada pelas filas e pelo Action Cable. | Para serviços Redis fora da configuração local padrão; em produção, definir a conexão. |
| `WEBHOOK_TOKEN` | Autenticar o recebimento de eventos. | Em produção; `dev-token` é apenas para desenvolvimento e teste. |
| `WORLD_CUP_API_URL` | Substituir o endereço do provedor inicial. | Opcional. |
| `ESPN_SCOREBOARD_URL` | Substituir o endereço do Scoreboard. | Opcional. |
| `FOOTBALL_DATA_API_TOKEN` | Habilitar a fonte complementar. | Opcional, com acesso à competição. |
| `PORT` | Alterar a porta usada no desenvolvimento. | Quando a porta padrão estiver ocupada. |

A arquitetura completa requer um processo web Rails, um worker Sidekiq, PostgreSQL e Redis. O ambiente de produção também precisa da configuração dos segredos Rails, assets e conexões de banco usadas em seu deploy. Esta seção não constitui um procedimento de implantação validado.

## Testes e qualidade

```bash
bin/rails test
bin/rails db:test:prepare test:system
bin/rubocop
bundle exec brakeman --no-pager
```

A suíte cobre o contrato e a autenticação do webhook, processamento idempotente,
assinaturas, estatísticas, reconciliação de partidas, fallback do acervo completo,
rankings, filtros, exclusão de atualizações simultâneas e estados de sucesso e
falha da sincronização. APIs são substituídas por clientes de teste para que a
suíte não dependa de rede ou credenciais.

Os testes de sistema usam Chrome em modo headless e cobrem rankings, navegação
entre fases e detalhes das partidas, criação e remoção de alertas, layout no
celular e atualização automática do painel após a execução do job. Os serviços
externos são substituídos durante o teste da sincronização; Redis e Sidekiq não
precisam estar em execução para rodar a suíte.

O repositório inclui [workflow de CI](.github/workflows/ci.yml) com análise estática, auditoria de dependências, lint e testes. A existência do workflow não informa o resultado da última execução; consulte o GitHub Actions para verificar o estado atual. Não são apresentadas métricas de cobertura, carga ou latência sem medição.

## Limitações atuais

- Autenticação de torcedores e autorização de operações administrativas ainda aparecem no roadmap; o estado atual deve ser tratado como demonstração.
- Alertas são transmitidos no navegador. Entrega por e-mail ou push ainda não está implementada.
- Persistência de um evento e transmissão ao navegador são operações separadas. Se o broadcast falhar após a gravação, repetir o evento não garante reenviar a notificação, pois a proteção de duplicidade impede novo processamento.
- O acervo local mantém a demonstração disponível, mas não garante a atualização dos dados externos.
- A identidade canônica das partidas depende das regras de reconciliação e dos dados recebidos dos provedores.
- Rankings finais são snapshots versionados; o botão de atualização não os recalcula.
- Não há resultados de benchmark que comprovem capacidade de processamento ou latência de entrega.

## Próximos passos

Propostas de evolução, ainda não apresentadas como funcionalidades concluídas:

- Autenticação de torcedores e autorização para operações administrativas.
- Controle durável da entrega de notificações, avaliando outbox e retentativas independentes da gravação do evento.
- Preferências por canal de entrega, como e-mail e push.
- Métricas de latência, falhas, origem dos dados e painel de observabilidade.
- Testes de falha entre persistência e broadcast, com verificação da recuperação.
- Adaptar o domínio para outras competições e edições.
- Documentar e validar a implantação completa dos processos web e worker.

## A aplicação em funcionamento

As imagens deste repositório são capturas reais da aplicação executando localmente,
com os dados históricos carregados pelo seed.

### Partida: placar, estatísticas e lances

![Detalhes da final entre Espanha e Argentina, com placar e estatísticas](docs/screenshots/match.png)

### Experiência no celular

<p align="center">
  <img src="docs/screenshots/mobile.png" alt="Painel do HexaAlerts em uma tela de celular, com o estado da competição e o ranking de seleções" width="320">
</p>

Para gerar novamente as imagens, inicie a aplicação, carregue os seeds e execute:

```bash
SCREENSHOT_BASE_URL=http://localhost:3000 bin/screenshots
```

O script usa Chrome em modo headless via Selenium, salva as três imagens em
`docs/screenshots` e verifica se há transbordamento horizontal no celular.