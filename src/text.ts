/** 文字列ユーティリティ。練習用 Issue はここに機能を足していく。 */

/**
 * 文字列を URL に使える slug に変換する。
 * 非 ASCII 文字は空白と同じ扱い（除去）。ASCII 部分が残らない場合はエラーを投げる。
 * @throws {Error} 入力から有効な slug を生成できない場合
 */
export function slugify(input: string): string {
  const slug = input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  if (slug === "" && input.trim() !== "") {
    throw new Error(
      "Cannot generate slug: input contains no ASCII alphanumeric characters",
    );
  }
  return slug;
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
