# Design

## Context

См. proposal. Neogit runner имеет native Username/Password handlers, cancel
останавливает Git process. Existing Git errors проверяет push/local remote,
но не challenge/credentials. Готовы Editor SDK6/14, host Python и Git.

## Goals / Non-Goals

Goals: HTTP credential cancel/rejection/retry, masked input, local/remote refs,
быстрый Push до первого refresh без Lua error; настоящий pre-push hook.
Non-Goals: product auth manager/helper, real tokens/accounts/OAuth/SSH, Mac/GUI,
новый SDK/service dependency и общая test infrastructure.

## Decisions

- Source profiles4738415166800/4773315743900: нет Username/Git process.
  Diagnostic5845225903000 подтвердил nil hooks и точный стек hooks.lua:70 →
  cli.to_process → push_to. Repo.empty_state не содержит hooks, первый refresh
  публикует их асинхронно. `hooks.exists` трактует отсутствующий metadata как
  пустой список; флаг влияет лишь на native preview/error UI, не на argv/hooks.
  Latest upstream hooks blobadb248d4 также не содержит guard. Один companion
  с before/after SHA, прежний pin; удалить после upstream эквивалента и E2E.
- IDE-126: source input diagnostic6144285730200 доказал передачу точного
  fixture secret Neogit и HTTP password_length=0. Native runner посылает CR+LF;
  diagnostic6211541205600 с одним CR успешно отправил тот же commit через HTTP.
  Ответ в PTY завершается одним Enter (CR) на всех ОС, без OS ветвления.
  Последний upstream runner blob39a6808f сохраняет CR+LF. Companion runner.lua
  добавляется в тот же manifest; отдельный credential manager не нужен.

- stdlib Python fixture HTTP server слушает127.0.0.1:0, после Basic challenge
  делегирует настоящий smart HTTP штатному `git http-backend`. CGI variables
  по официальной документации https://git-scm.com/docs/git-http-backend.
- Синтетические credentials фиксированы в test fixture, audit хранит лишь
  has_auth/authorized/status. UI должен маскировать secret; remote не меняется
  при отмене/ошибке. Никаких production credentials/global config.
- Native Git helper отключается только в fixture repository, GIT_ASKPASS/SSH_ASKPASS
  очищены в child env; GCM не открывает внешний UI. Git всё равно настоящий.
- Backend HTTP sidecar запускается как job дочернего Editor, входит в owned
  process scope и явно завершается перед штатным stop; no orphan service.
- Status→P u/input/inputsecret/ошибка/history/retry клавиатурой; RPC только
  наблюдает public cli.history/server metadata. Bare remote HEAD проверяет Git CLI.
- Предварительное состояние remote создаёт file transport fixture setup;
  acceptance push идёт только через HTTP challenge с native input.
- Fixture pre-push пишет marker: проверяем исполнение настоящего Git hook,
  отсутствие --no-verify и сохранение keyboard credential flow.
- Неверный пароль обрабатывает штатный Neogit runner: до трёх попыток, cached
  username и новый inputsecret. Не создаём новый Push между этими попытками.
  Audit содержит лишь совпадение fixture credentials/длину, без самого пароля.

## Risks / Trade-offs

- Blocking credential prompts → nvim_get_mode/screen predicates, без sleeps.
- После отказа generic force prompt → No только при ожидаемом Force confirm.
- Container network none оставляет loopback; внешней сети fixture не требует.
- Secret не попадает в stdout/audit; это тестовые значения, не user tokens.
