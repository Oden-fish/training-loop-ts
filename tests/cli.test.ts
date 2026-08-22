import { describe, expect, it } from "vitest";
import { PassThrough } from "node:stream";
import { run } from "../src/cli";

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

  it("出力バッファが埋まっても全行を取りこぼさない", async () => {
    const lines = Array.from({ length: 50 }, (_, i) => `Line ${i}`);
    const input = feed(lines);
    // highWaterMark を小さくして write() に false を返させ、drain 待ちの経路を通す
    const output = new PassThrough({ highWaterMark: 1 });
    const outputText = collect(output);

    await run(input, output);
    output.end();

    expect(await outputText).toBe(lines.map((_, i) => `line-${i}\n`).join(""));
  });
});
