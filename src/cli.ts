/** 標準入力を1行ずつ slug にして標準出力に流す CLI。 */

import { once } from "node:events";
import { createInterface } from "node:readline";
import type { Readable, Writable } from "node:stream";
import { slugify } from "./text.ts";

/**
 * バックプレッシャーを尊重して1行書き出す。
 * write() が false を返したのに書き続けると、遅い出力先の分だけメモリに溜まってしまう。
 */
async function writeLine(stream: Writable, text: string): Promise<void> {
  if (!stream.write(text)) {
    await once(stream, "drain");
  }
}

/**
 * 入力の各行を slug 化して output に書き出す。
 *
 * 入力全体をメモリに載せないよう readline で1行ずつ読む。
 * slug を作れない行はスキップし、理由を error に書いてから後続の行の処理を続ける
 * （1行の失敗で残り全部を捨てないため）。
 */
export async function run(
  input: Readable,
  output: Writable,
  error: Writable = process.stderr,
): Promise<void> {
  const lines = createInterface({ input, crlfDelay: Infinity });
  for await (const line of lines) {
    let slug: string;
    try {
      slug = slugify(line);
    } catch (cause) {
      await writeLine(error, `${(cause as Error).message}: ${line}\n`);
      continue;
    }
    await writeLine(output, `${slug}\n`);
  }
}

// エントリーポイント。テストは run() を直接呼ぶので、import 時には走らせない。
if (import.meta.filename === process.argv[1]) {
  await run(process.stdin, process.stdout);
}
