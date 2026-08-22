/** 文字列ユーティリティ。練習用 Issue はここに機能を足していく。 */

/** 文字列を URL に使える slug に変換する。 */
export function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}
