/** 文字列ユーティリティ。練習用 Issue はここに機能を足していく。 */

/** 文字列を URL に使える slug に変換する。 */
export function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

/**
 * 文字列を指定長で切り詰める。超過時は末尾を … (U+2026) にし、全体が maxLength 文字になる。
 * @throws {RangeError} maxLength が 1 未満の場合
 */
export function truncate(input: string, maxLength: number): string {
  if (maxLength < 1) {
    throw new RangeError(`maxLength must be at least 1, got ${maxLength}`);
  }
  if (input.length <= maxLength) {
    return input;
  }
  return input.slice(0, maxLength - 1) + "\u2026";
}
