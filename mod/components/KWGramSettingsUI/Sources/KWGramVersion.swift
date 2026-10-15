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
public let kwGramVersionString = "v1.6.1"

public let kwGramChangelogText = """
Диагностика загрузки. Предыдущая попытка не устранила зависание: лента всё ещё остаётся пустой, а шапка — вечным «Обновление...», поэтому эта сборка добавляет наблюдение, а не очередную непроверенную починку.

Откройте «О KW Gram» (тап по карточке вверху) — секция «ДИАГНОСТИКА ЗАГРУЗКИ» показывает, на каком шаге обмен с сервером остановился: сам запрос getDifference, ошибка RPC, расхождение pts, отбраковка проверкой или пропуск без повторной попытки. Значение живое и обновляется прямо на экране.

Заголовок, Bot Login и остальные функции работают без изменений.
"""
