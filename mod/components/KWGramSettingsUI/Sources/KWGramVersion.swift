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
public let kwGramVersionString = "v1.1.2"

public let kwGramChangelogText = """
Профиль: новый раздел. «Визуальный +888» и «Визуальный рейтинг» переехали сюда из «Подарок». «+888» локально заменяет строку номера в собственном профиле; нажатие и удержание копируют отображаемый номер. Рейтинг открывает редактор с готовыми образцами, уровнем 1–100 и независимым ползунком очков.

Время в ник: пока включено, ваша фамилия в Telegram показывает текущее московское время (например, 09:35) и обновляется каждую минуту; при выключении на место возвращается прежняя фамилия.

Подарки: здесь остались подарки, локальные балансы, коллекция и маркет. «Коллекция и маркет» для локальных подарков, отдельные журналы и статистика Stars, TON и рублей. Покупки, продажи, передачи и ручные корректировки попадают в историю автоматически.
"""
