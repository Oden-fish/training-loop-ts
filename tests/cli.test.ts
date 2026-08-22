import { describe, expect, it } from "vitest";
import { PassThrough, Writable } from "node:stream";
import { run } from "../src/cli";

/**
 * 書き込み完了を次のイベントループまで遅らせる出力先。
 * highWaterMark が 1 なので、書き込み中に次の write() が来ると false を返し、
 * バックプレッシャーの経路（drain 待ち）が実際に通る。
 */
class SlowSink extends Writable {
  private readonly chunks: string[] = [];
  /** _write が呼ばれた時点で内部バッファに残っていたバイト数の最大値 */
  maxQueuedBytes = 0;
  drainCount = 0;

  constructor() {
    super({ highWaterMark: 1 });
    this.on("drain", () => {
      this.drainCount += 1;
    });
  }

  _write(
    chunk: Buffer,
    _encoding: BufferEncoding,
    callback: (error?: Error | null) => void,
  ): void {
    this.chunks.push(chunk.toString());
    this.maxQueuedBytes = Math.max(this.maxQueuedBytes, this.writableLength);
    setImmediate(callback);
  }

  get text(): string {
    return this.chunks.join("");
  }
}

/** 1行は最長 "line-49\n" の 8 バイト。数行分を上限にしておけば「溜め込んでいない」と言える。 */
const MAX_QUEUED_BYTES = 32;

function collect(stream: PassThrough): Promise<string> {
  return new Promise((resolve) => {
    const chunks: Buffer[] = [];
    stream.on("data", (chunk: Buffer) => chunks.push(chunk));
    stream.on("end", () => resolve(Buffer.concat(chunks).toString()));
  });
}

function feed(lines: string[]): PassThrough {
  const input = new PassThrough();
  input.end(lines.join("\n") + "\n");
  return input;
}

describe("run", () => {
  it("通常の文字列を slug 化して出力する", async () => {
    const input = feed(["Hello, World!"]);
    const output = new PassThrough();
    const outputText = collect(output);

    await run(input, output);
    output.end();

    expect(await outputText).toBe("hello-world\n");
  });

  it("空行はそのまま空行として出力する", async () => {
    const input = feed([""]);
    const output = new PassThrough();
    const outputText = collect(output);

    await run(input, output);
    output.end();

    expect(await outputText).toBe("\n");
  });

  it("複数行を行単位で処理する", async () => {
    const input = feed(["Hello World", "", "Foo Bar"]);
    const output = new PassThrough();
    const outputText = collect(output);

    await run(input, output);
    output.end();

    expect(await outputText).toBe("hello-world\n\nfoo-bar\n");
  });

  it("非 ASCII のみの行はスキップし stderr にエラーを出力する", async () => {
    const input = feed(["日本語のみ"]);
    const output = new PassThrough();
    const error = new PassThrough();
    const outputText = collect(output);
    const errorText = collect(error);

    await run(input, output, error);
    output.end();
    error.end();

    expect(await outputText).toBe("");
    expect(await errorText).toContain("Cannot generate slug");
  });

  it("エラー行があっても後続の行を処理し続ける", async () => {
    const input = feed(["good-line", "日本語", "another-line"]);
    const output = new PassThrough();
    const error = new PassThrough();
    const outputText = collect(output);
    const errorText = collect(error);

    await run(input, output, error);
    output.end();
    error.end();

    expect(await outputText).toBe("good-line\nanother-line\n");
    expect(await errorText).toContain("Cannot generate slug");
  });

  it("出力が詰まっているときは書き込みを待ち、バッファを積み上げない", async () => {
    const lines = Array.from({ length: 50 }, (_, i) => `Line ${i}`);
    const sink = new SlowSink();

    await run(feed(lines), sink);

    expect(sink.text).toBe(lines.map((_, i) => `line-${i}\n`).join(""));
    // drain を待たずに書き続けると、未処理の行がすべて内部バッファに積み上がる。
    // 待っていれば、内部に残るのは書き込み中の1行だけになる。
    expect(sink.drainCount).toBeGreaterThan(0);
    expect(sink.maxQueuedBytes).toBeLessThan(MAX_QUEUED_BYTES);
  });
});
