# Design

## Context

Content.IE5 links из §162 имеют directory reparse tag, target отсутствует и содержит forward slashes после NT prefix. Python no-follow lstat/readlink читает metadata, UV lstat/readlink возвращает nil. UV scandir type=link; uv.fs_rmdir проверенного собственного link успешно удалил только link.

## Goals / Non-Goals

Цель — удалить owned runtime с directory links, сохраняя target и маркер при отказе. Не исправляем libuv/SDK и не завершаем процессы, не меняем timeout и не следуем ссылкам.

## Decisions

- Обходить только directory entries с kind=directory. Для kind=link сначала unlink, на Windows directory-link fallback nonrecursive rmdir. Не использовать target stat для классификации: для malformed junction он не работает.
- Native filesystem fixture: target вне удаляемого профиля, но тоже создан этим тестом под checkout TEMP; sentinel доказывает отсутствие traversal. Dangling и Windows malformed NT target проверяются отдельно, без admin.
- Source RED должен воспроизвести текущий cleanup failure. Прежние runtime lifecycle/ownership/file-lock и descendants E2E защищают сохранённые инварианты.

## Open Questions

Конкретный Windows компонент, создавший Content.IE5 в private HOME, не установлен; для корректного удаления links это не требуется.
