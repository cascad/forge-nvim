# Проверка 2026-11-13

## Результат

- Windows:24 distinct PASS на конечном runtime6/16. Auth cancel6268974488500
  из v2 и reject6538339947200 из v4;22 controls из одного следующего прогона
  (sequence3/conflicts4/backports15). Это не полный PASS v2: он дал1/1, а
  обновлялся только retry predicate и failure observability, runtime прежний.
- Ubuntu: один final script, auth2+sequence3+conflicts4+backports15=24 PASS.
  Auth3588482326369/3592177129872; native11 profiles в каждой ОС.
- Все выбранные shutdown: exit0/signal0, hard_kill=false, API errors[], scope
  active_after0/ok. HTTP sidecar работал перед jobstop, затем завершён; реальный
  pre-push marker, masked input, refs/clean и authenticated POST200 подтверждены.
- Windows old rebase-abort gate теперь PASS на новой версии, исходный IDE-124
  timeout сохранён. Его историческую причину без source лога не приписываем guard.

## Дефекты и промежуточные результаты

Source4738415166800/4773315743900:0/2, Push не создан; hook diagnostic
5845225903000 подтвердил nil metadata и точный стек. После hook guard
6017154110000/6033264429800:0/2, теперь credentials доступны, но верный secret
отклонён. Input diagnostic6144285730200: точный secret отправлен runner,
HTTP password_length0. Diagnostic6211541205600 с одним CR: настоящий push PASS;
observer-only result не считается acceptance.

Permanent runner CR version: v2 cancel PASS, reject6275313251300 FAIL ожидания
notification+prompt. V3 reject6382683624600 и observe6463749626600 сохранили FAIL;
pre-cleanup capture показал mode r/blocking и видимый Authentication Failed /
Press ENTER. Причина ожидания подтверждена: нужен native Enter, а не таймер.
V4 добавляет acknowledgement только ожидаемого auth failure (native E errors
не принимаются); reject PASS. Исходные отчёты/ошибки не удалены, unchanged green
retry нет. Некоторые промежуточные cleanup FAIL явно сохранены, не спрятаны.

## Артефакты и границы

Host .tests/git-auth-{native-windows,target-windows,v2-windows,v3-windows,
v4-windows,controls-windows,ubuntu}; diagnostic*.txt; editor-e2e profiles.
Audit .tests/git-auth-final-audit.json содержит verdicts и11 shutdown каждой ОС,
current manifest67 pins/6 dependencies/16 files, private Neogit SHA payload.
Ubuntu host profiles находятся в .tests/ubuntu/editor-e2e; script
.tests/ubuntu/git-auth-20261113.sh создаёт private Neogit overlay на готовом
image f63a05ca, network none, без lifecycle/build/download.

SDK SHA74AFF15B3B6BC288753B721365B088AB44C9B2BFFF152F8D27F5885B4B1C6AD9
и67 pins прежние. Не проверены Mac/physical/OAuth/SSH agent/user helper/real
remote account. Общий regression и прочие прежние native gates не объявлены PASS.
Установленная сборка требует :Lazy build neogit и перезапуск; test SDK обновлён
явно, user cache не изменялся. Local companions удаляются отдельно после upstream
эквивалентов и тех же workflow checks. Прежние frozen drafts не входят в change.
