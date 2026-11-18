# Design

## Decisions

В directory ветке check_owned после lstat определить ровно top-level kit/tmp
и пропустить рекурсию. Directory/link самой границы проверяется прежде этого;
foreign root junction/symlink по-прежнему ошибка. Все прочие subtrees прежние.
Это одинаковая policy Windows/Linux/macOS, без распознавания Windows tags.
Ничего не удалять: временный socket может принадлежать ещё работающему процессу.

Native tests создают настоящий AF_UNIX через standard Go net.ListenUnix с коротким
relative pathname, чтобы не упираться в sun_path limit на длинных test paths.
Closed и live endpoints остаются при repeat, stdout/ownership/native launch
проверяются. Windows CPython не предоставляет AF_UNIX, поэтому один native
Go helper используется на всех ОС без platform FFI. Foreign tmp root и
persistent external link остаются отказами.

## Non-Goals

Изменение linker policy, очистка всех пользовательских tmp, новый temp manager,
Windows SDK patch, принятие ошибки EACCES в произвольном config/runtime file,
ослабление проверок runtime hashes или active editor shutdown.
