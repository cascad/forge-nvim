# Verification

2026-11-18, source c649398.4/5 tasks выполнены; native Mac остаётся2.1.

## Feature

Новый frontend: allow/deny в Options/Plan, PTY default No, headless deny,
preview/check без загрузки; root flags обеих ОС, лог/JSON policy. Parent env
не подменяет frontend consent. Private installer даёт auto только tools child
до init, остальные phases local. Setup проверяет public Mason graft_env, если
process module уже загружен: поздняя смена одной vim.env не исправляет snapshot.
Native readiness при allow принимает Go1.21+, при deny прежний1.26+, ready
receipts skip compiler probe. GOPROXY/GOSUMDB/GOENV/native SDK homes сохранены.

## Native iteration

| Запуск | Windows | Ubuntu |
|---|---|---|
| UI build |11.84s, d49c663c… |14.58s, dd4a5267… |
| Initial2 registry +5 Python |1795006649958698700 |1795006662354140857 |
| Go failure/late policy affected3 |go-policy-affected-1795006936777511600,26.48s,PASS |go-policy-affected-1795006956481106310,12.42s,PASS |
| IDE stage affected3 |Tools.test_10/11/12,0.206s,PASS |0.356s,1 PASS/2 native older-Go SKIP |
| Allow preview/check strengthened case |1 PASS,20.393s |1 PASS,5.382s |

Latest per-case aggregate:53 Python PASS +10 registry PASS/2 info SKIP Windows;
50 Python PASS/3 platform SKIP +10 registry PASS/2 info SKIP Ubuntu.11 new Go
cases: Windows11 PASS, Ubuntu10 PASS/1 older-SDK SKIP. Controls: UI13, source
bootstrap6, shared SDK settings11, existing IDE tools12, CLI batch2/root trace8.
Raw initial FAIL не заменены: оба OS initial Go10 дали2 FAIL; IDE tools дали
Windows3 FAIL /Ubuntu1 FAIL+2 SKIP. Повторялись только affected cases.

## Причины повторов

- Test offline reuse вызывал create_new result.json второй раз, останавливая
  frontend до tools; fixture удаляет свой прошлый report перед повтором.
- Первый failure marker ready=false — reservation, не опубликованный kit;
  тест теперь проверяет ready=false и отсутствие active bin/runtime.
- Existing false-success diagnostic заранее загружал Mason с auto, ожидая,
  что поздняя смена vim.env изменит cache. Fixture теперь повторяет private
  pre-init boundary; production guard проверяет actual public captured env.
- Первый адресный запуск IDE unittest использовал имя без Tools.;3 loader
  ERROR сохранены отдельно, реальные кейсы тогда не исполнились. После исправления
  селектора повторены только эти3; Go affected3 не повторялись.
- Первый Ubuntu build не нашёл offline crates. Использован уже существующий
  vendor.tar.gz в private container /tmp; network/engine config не менялись.

## Что доказано и границы

Native frontend/HTTP source/private Neovim, PTY yes/no/cancel, CLI flags,
pre-init Go policy, actual Mason process.graft_env/spawn и настоящий go install
локального fixture tool проверены. Export executable запускается. На Windows
реальный старый Go1.23.3 допускается при allow; это не полный gopls workflow
на этом SDK. Go module1.99.0 при allow реально обращается к private unavailable
proxy и оставляет native ошибку, при deny не обращается. Прежний kit marker и
runtime SHA сохранены; поздний snapshot не запускает build. Foreign nvim и
test GOENV snapshots сохранены. SDK в пользовательскую ОС не устанавливался.

Receipt/catalog/install-completion контролируются fixture для одного пакета;
full Default, successful fresh compiler download, совместимость всех LSP/SDK
и native Mac не заявлены. Upstream native Go selection реализован самим Go,
не downloader fride. Proxy/checksum settings в тестах сохранены без обхода.

Оригинальные .tools UI/Neovim, SDK/locks/backports frozen. UI payloads только
в ignored .tests/toolchain-research/go-policy-ui и Ubuntu peer; host tmp на F.
Docker existing/offline/limits2CPU/3GiB, без Desktop/WSL management. Logs и
go-policy-composite.json лежат в .tests/toolchain-research. Strict/syntax/
diff/raw+staged journal guards PASS. Full regression не повторялся.
