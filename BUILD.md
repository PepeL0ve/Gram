# KW-Gram — инструкция по сборке

Этот файл — памятка для агента/разработчика: как устроена сборка, как её запускать,
как чинить ошибки компиляции и как выкладывать релиз. Не удалять.

## 1. Устройство репозитория

Репозиторий **не содержит сам Telegram**. Сюда входят только:

- `mod/telegram-ios.patch` — патч поверх закреплённого коммита upstream Telegram-iOS
  (`36ded15d530ed43a293de5a9f8c1679e86f0e588`);
- `mod/components/` — собственные модули KWGram (KWGramCore, KWGramSettingsUI и др.),
  которые CI копирует в `submodules/TelegramUI/Components/KWGram/`;
- `mod/apply-profile-visuals.py` — скрипт правок профиля, выполняется после патча;
- `.github/workflows/build-ipa.yml` — сборка.

Исходники upstream на диске не лежат — их забирает CI. Локально доступны только
файлы из `mod/`, поэтому все проверки API Telegram/Postbox делаются либо по патчу,
либо по исходникам на закреплённом коммите через raw.githubusercontent.com.

## 2. Как запустить сборку

Сборка **ручная** (`workflow_dispatch`), по коммиту не запускается.

Через веб: Actions → **Build IPA** → **Run workflow** → ветка `main`.

Через API (без `gh` CLI, токен в файле `.ghtoken`):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
. "$env:TEMP\opencode\gh.ps1"                       # даёт функцию gh-api
gh-api "/repos/FLYXSE/KW-Gram/actions/workflows/build-ipa.yml/dispatches" -method POST `
       -body @{ ref = 'main' } | Out-Null
```

Либо точный перезапуск готового рана:

```powershell
gh-api "/repos/FLYXSE/KW-Gram/actions/runs/<run_id>/reruns" -method POST
```

## 3. Что делает CI (по шагам)

1. Checkout KW Gram → 2. Select Xcode 26.2 → 3. Checkout Telegram-iOS (пин) →
4. **Apply the KW Gram patch** (`git apply mod/telegram-ios.patch`) →
5. Копирование `mod/components/*` в дерево Telegram → `apply-profile-visuals.py` →
6. Fake-signing identity в keychain → 7. Build configuration →
8. Restore Bazel cache → 9. **Build device IPA** (`Make.py build --configuration=release_arm64`) →
10. Save Bazel cache → 11. Upload artifact **`KWGram-ipa`** (= `output/Telegram.ipa`).

Чистая сборка ~30 мин; с тёплым кешем ~15 мин. Кеш сохраняется **и при провале**
(ключ `telegram-bazel-cache-xcode-26.2-<run_id>`), поэтому итерации по ошибкам
компиляции идут быстро — не удалять кеш руками.

## 4. Как смотреть результаты

```powershell
. gh.ps1
$r = gh-api "/repos/FLYXSE/KW-Gram/actions/runs?per_page=8"
$r.workflow_runs | Select-Object run_number, status, conclusion, head_sha
```

Лог упавшего шага (текст):

```powershell
# id рана → jobs → logs (zip)
Invoke-WebRequest -Headers $script:GH `
  -Uri "https://api.github.com/repos/FLYXSE/KW-Gram/actions/runs/<id>/logs" -OutFile logs.zip
```

Искать ошибки компиляции по строкам `error:` — сообщения Swift компилятора
дают точный файл:строка:колонка.

## 5. Грабли компиляции KWGram-модулей (все уже встречались)

Все цели KWGram собраны с `-warnings-as-errors`.

1. **`postbox.transaction { }` возвращает `Signal`, а не `Transaction`.**
   Синхронного чтения из Postbox нет. Правильно:

   ```swift
   let _ = (context.account.postbox.transaction { transaction in ... }
            |> take(1)
            |> deliverOnMainQueue).start(next: { value in ... })
   ```

2. **Заголовок чата/пира нельзя получить синхронно.** `EnginePeer(PeerId(id))` —
   не скомпилируется (`PeerId` не `Peer`). Правильно:

   ```swift
   let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).start(next: { peer in
       let title = peer?.compactDisplayTitle ?? ""
   })
   ```

3. **`MessageIdNamespaces` — передавать литерал множества:**
   `namespaces: .just([Namespaces.Message.Cloud])` (а не `.just(Namespaces.Message.Cloud)` —
   есть перегрузка `just(Set<Int32>)`, и компилятор выбирает её).

4. **`aroundMessageHistoryViewForLocation`:** аргумент `anchor:` идёт сразу после
   `location`, до `ignoreMessagesInTimestampRange`. Перегрузка с `anchor: MessageId`
   в позиции 2 конфликтует по порядку аргументов.

5. **Патч `mod/telegram-ios.patch` — формат строгий.** После любой правки патча
   пересчитать количество строк в заголовках ханков `@@ -a,b +c,d @@` и проверить
   все ханки скриптом `check-patch.ps1`. CI делает `git apply` — один неверный
   счётчик строк ломает весь шаг «Apply the KW Gram patch».

6. **`core.autocrlf=true`:** в индекс патч и Swift-файлы попадают в LF.
   `git apply` в CI работает с LF-версией.

## 6. Релиз (.ipa → GitHub Release)

1. Скачать артефакт (нужен токен):

   ```powershell
   $a = gh-api "/repos/FLYXSE/KW-Gram/actions/runs/<run_id>/artifacts"
   $art = $a.artifacts | Where-Object name -eq 'KWGram-ipa'
   Invoke-WebRequest -Headers $script:GH `
     -Uri "https://api.github.com/repos/FLYXSE/KW-Gram/actions/artifacts/$($art.id)/zip" `
     -OutFile ipa.zip
   Expand-Archive ipa.zip -DestinationPath ipa
   ```

   Внутри — `Telegram.ipa`.

2. Создать релиз. **`target_commitish` — только полный SHA** (короткий даёт 422):

   ```powershell
   $sha = (git rev-parse HEAD).Trim()
   @{ tag_name='v1.2.0'; target_commitish=$sha; name='KW-Gram v1.2.0'
      body='...'; draft=$false; prerelease=$false } |
     ConvertTo-Json | Set-Content -Encoding UTF8 body.json
   & curl.exe -sS -X POST -H "Authorization: Bearer $tok" -H "Accept: application/vnd.github+json" `
     -H "Content-Type: application/json" --data-binary "@body.json" `
     "https://api.github.com/repos/FLYXSE/KW-Gram/releases"
   ```

3. Загрузить арт-ефакт. **Эндпоинт загрузки — `uploads.github.com`, не
   `api.github.com`** (иначе 404):

   ```powershell
   & curl.exe -sS -X POST -H "Authorization: Bearer $tok" `
     -H "Content-Type: application/octet-stream" --data-binary "@Telegram.ipa" `
     "https://uploads.github.com/repos/FLYXSE/KW-Gram/releases/<release_id>/assets?name=KW-Gram-v1.2.0.ipa"
   ```

   Ответ `201` + `"state":"uploaded"` — успех; сверить `size` и `digest` (sha256).

4. **Удалить файл токена** `.ghtoken` после завершения работы.

## 7. Текущий статус (2026-10-11)

- `main` = `f3e3d92` — все ошибки компиляции вычинены (раны 12, 13).
- Run **#14 — success**, артефакт `KWGram-ipa` собран.
- Релиз **v1.2.0** опубликован: <https://github.com/FLYXSE/KW-Gram/releases/tag/v1.2.0>
  (ассет `KW-Gram-v1.2.0.ipa`, 76 368 560 байт, sha256 `3266e870…15e4`, fake-signed —
  перед установкой переподписать).
