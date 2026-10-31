-- Самопроверки индекса требований tests/lib/spec_index.lua (add-wezterm-spec-checks, задача 1.5).
local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
local B = dofile(r .. '/tests/lib/bootstrap.lua')
local T = require('check')
local S = require('spec_index')

T.check('SELF: индекс репо содержит все заголовки `### Requirement:` из openspec/specs', function()
  -- Независимый подсчёт — как `grep -h '^### Requirement:' openspec/specs/*/spec.md | wc -l`.
  local expected = 0
  for _, f in ipairs(vim.fn.glob(B.root .. '/openspec/specs/*/spec.md', false, true)) do
    for _, line in ipairs(vim.fn.readfile(f)) do
      if line:match('^### Requirement:') then expected = expected + 1 end
    end
  end
  local idx = S.build(B.root)
  T.ok(expected > 0, 'в openspec/specs нет требований')
  T.eq(#idx.order, expected, 'число ID в индексе')
  local n = 0
  for _ in pairs(idx.ids) do n = n + 1 end
  T.eq(n, expected, 'ID уникальны')
  -- Области включают и ADDED активных changes: editor-bootstrap вводит IDE.
  T.eq(idx.areas, { WT = true, MAC = true, IDE = true }, 'области ID основного индекса и changes')
end)

T.check('SELF: scan_ids не путает WT-CLIP-1 и WT-CLIP-10 и знает области', function()
  T.eq(S.scan_ids('см. WT-CLIP-10, WT-CLIP-1; XWT-CLIP-2 и FOO-BAR-3', { WT = true }), { 'WT-CLIP-10', 'WT-CLIP-1' })
  T.eq(S.scan_ids('WT-CLIP-1-b'), { 'WT-CLIP-1' })
end)

T.check('SELF: leading_ids берёт ID только из начала имени проверки', function()
  T.eq(S.leading_ids('WT-KEYS-4 WT-KEYS-7 пересечение'), { 'WT-KEYS-4', 'WT-KEYS-7' })
  T.eq(S.leading_ids('WT-CLIP-1, WT-CLIP-2: копирование'), { 'WT-CLIP-1', 'WT-CLIP-2' })
  T.eq(S.leading_ids('WT-CLIP-1-b вариант'), { 'WT-CLIP-1' })
  T.eq(S.leading_ids('SELF: про WT-CLIP-1'), {})
  T.eq(S.leading_ids('WT-CLIPX без номера'), {})
end)

T.check('SELF: parse_proverka различает пути tests/… и пункты `вручную (…)`', function()
  local p = S.parse_proverka('tests/install-macos.scenarios.sh (S1, S6); вручную (tests/manual/wezterm-windows.md, W2, W3)')
  T.eq(p.paths, { 'tests/install-macos.scenarios.sh' })
  T.eq(p.manual, {
    { file = 'tests/manual/wezterm-windows.md', item = 'W2' },
    { file = 'tests/manual/wezterm-windows.md', item = 'W3' },
  })
  T.eq(p.manual_free, false)
  local free = S.parse_proverka('tests/x.sh; вручную — `wezterm ls-fonts`')
  T.eq(free.paths, { 'tests/x.sh' })
  T.eq(free.manual, {})
  T.eq(free.manual_free, true, 'свободная ручная пометка не в формате review-baseline')
end)

T.check('SELF: parse_spec собирает строки `Проверка:` только своего требования', function()
  local reqs = S.parse_spec(table.concat({
    '## Requirements',
    '### Requirement: WT-AA-1 Первое',
    'Проверка: tests/a.test.lua (x)',
    'Проверка выделения — это не строка проверки.',
    '#### Scenario: s',
    '### Requirement: WT-AA-2 Второе',
    'Платформы: все',
  }, '\n'))
  T.eq(#reqs, 2)
  T.eq(reqs[1].id, 'WT-AA-1')
  T.eq(reqs[1].title, 'Первое')
  T.eq(#reqs[1].proverka, 1)
  T.eq(reqs[1].proverka[1].paths, { 'tests/a.test.lua' })
  T.eq(reqs[2].proverka, {})
end)

T.check('SELF: parse_delta видит ADDED, MODIFIED и RENAMED', function()
  local d = S.parse_delta(table.concat({
    '## RENAMED Requirements',
    '- FROM: `### Requirement: WT-AA-6 Старое`',
    '- TO: `### Requirement: WT-AA-6 Новое`',
    '## ADDED Requirements',
    '### Requirement: WT-AA-9 Новое требование',
    '## MODIFIED Requirements',
    '### Requirement: WT-AA-2 Изменённое',
  }, '\n'))
  T.eq(vim.tbl_map(function(x) return x.id end, d.added), { 'WT-AA-9' })
  T.eq(vim.tbl_map(function(x) return x.id end, d.modified), { 'WT-AA-2' })
  T.eq(vim.tbl_map(function(x) return x.id end, d.renamed), { 'WT-AA-6' })
end)

T.check('SELF: чек-лист review-baseline — код пункта, ID, последняя строка `Проверено:`', function()
  local items = S.parse_checklist(table.concat({
    '# Ручные проверки WezTerm — Windows',
    'Формат результата: `Проверено: <дата>, <ОС>, WezTerm <версия>, раскладка <…> — совпало | расходится: …`',
    '## wezterm-key-ownership',
    '### W2 — Alt+Space и Alt+F4',
    'Требования: WT-KEYS-9. Источник: div. 34.',
    'Проверено: 2026-09-28, Windows 11, WezTerm 20240203-110809-5046fc22, раскладка en — расходится: Alt+F4 не закрывает',
    'Проверено: 2026-09-29, Windows 11, WezTerm 20240203-110809-5046fc22, раскладка en/ru — совпало',
    '## wezterm-clipboard',
    '### W3 OSC 52 через ConPTY',
    'Требования: WT-CLIP-11, WT-CLIP-11.',
  }, '\n'))
  T.eq(#items, 2)
  T.eq({ items[1].code, items[1].title, items[1].capability }, { 'W2', 'Alt+Space и Alt+F4', 'wezterm-key-ownership' })
  T.eq(items[1].ids, { 'WT-KEYS-9' })
  T.eq(#items[1].verified, 2)
  T.ok(items[1].last:match('совпало$'), 'последняя строка — текущий статус: ' .. tostring(items[1].last))
  T.eq({ items[2].code, items[2].capability, items[2].last }, { 'W3', 'wezterm-clipboard', nil })
  T.eq(items[2].ids, { 'WT-CLIP-11' })
end)

T.finish()
