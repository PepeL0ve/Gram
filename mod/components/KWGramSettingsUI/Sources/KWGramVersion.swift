import Foundation

/// Single source of truth for the version string and changelog shown in the hub's hero row
/// and the "About KW Gram" screen (tap the hero row to see it).
///
/// VERSIONING POLICY: three numbers after "v".
/// - 1st digit — a mega-change (major rewrite / architecture).
/// - 2nd digit — big new features.
/// - 3rd digit — small features and fixes.
/// Bump the appropriate digit on every feature/fix release and rewrite
/// `kwGramChangelogText` to describe what's actually in that build. This is the one place
/// both screens read from, so a single edit here keeps them in sync.
public let kwGramVersionString = "v1.6.0"

public let kwGramChangelogText = """
Исправлены входящие сообщения: в v1.5.0 лента могла зависнуть в «Обновление», и новые входящие переставали приходить вовсе. Причина — серверное удаление сообщений ставилось прямо во время разбора getDifference и вмешивалось в нумерацию pts, из-за чего обновление аккаунта не завершалось. Теперь отфильтрованные сообщения удаляются на сервере отложенной свежей транзакцией — той же, что и при обычном удалении из чата. Сам мут ЛС работает как раньше.

Заголовок: в «Чаты» → «Заголовок» введите свой текст — он заменит «Чаты» и в шапке главного списка чатов, и на вкладке. Пустое поле вернёт стандартное «Чаты».

Bot Login: на экране ввода номера появилась кнопка «⋮» — вход по токену бота из @BotFather. Бот авторизуется как отдельный аккаунт на этом устройстве: штатный серверный вход auth.importBotAuthorization, дальше обычный аккаунт. Неверный токен — понятная ошибка, а не молчаливый сбой.
"""
