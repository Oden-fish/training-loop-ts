import { describe, expect, it } from "vitest";
import { parseDuration, slugify, truncate } from "../src/text";

describe("slugify", () => {
  it("空白と記号をハイフンにする", () => {
    expect(slugify("Hello, World!")).toBe("hello-world");
  });
  it("前後のハイフンを落とす", () => {
    expect(slugify("  --Hello--  ")).toBe("hello");
  });
  it("非 ASCII のみの入力でエラーを投げる", () => {
    expect(() => slugify("日本語のタイトル")).toThrow(Error);
  });
  it("非 ASCII 混在で ASCII 部分が残ればそれを返す", () => {
    expect(slugify("hello世界")).toBe("hello");
  });
  it("非 ASCII 混在でも ASCII 部分が空ならエラーを投げる", () => {
    expect(() => slugify("日本語！＃")).toThrow(Error);
  });
});

describe("truncate", () => {
  it("上限ちょうどの長さならそのまま返す", () => {
    expect(truncate("abcde", 5)).toBe("abcde");
  });
  it("上限+1 の長さなら末尾を … にして上限ちょうどにする", () => {
    expect(truncate("abcdef", 5)).toBe("abcd…");
  });
  it("上限より大幅に長い場合も上限ちょうどにする", () => {
    expect(truncate("abcdefghij", 3)).toBe("ab…");
  });
  it("空文字はそのまま返す", () => {
    expect(truncate("", 5)).toBe("");
  });
  it("上限が 1 なら省略記号だけ返す", () => {
    expect(truncate("abc", 1)).toBe("…");
  });
  it("上限が 0 なら RangeError を投げる", () => {
    expect(() => truncate("abc", 0)).toThrow(RangeError);
  });
  it("上限が負数なら RangeError を投げる", () => {
    expect(() => truncate("abc", -1)).toThrow(RangeError);
  });
});

describe("parseDuration", () => {
  it("時間のみをパースできる", () => {
    expect(parseDuration("1h")).toEqual({ ok: true, value: 3600 });
  });
  it("分のみをパースできる", () => {
    expect(parseDuration("30m")).toEqual({ ok: true, value: 1800 });
  });
  it("秒のみをパースできる", () => {
    expect(parseDuration("45s")).toEqual({ ok: true, value: 45 });
  });
  it("時分の組み合わせをパースできる", () => {
    expect(parseDuration("1h30m")).toEqual({ ok: true, value: 5400 });
  });
  it("時分秒の組み合わせをパースできる", () => {
    expect(parseDuration("2h5m10s")).toEqual({ ok: true, value: 7510 });
  });
  it("空文字で ok: false を返す", () => {
    const result = parseDuration("");
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error).toBeTypeOf("string");
    }
  });
  it("アルファベットだけの入力で ok: false を返す", () => {
    const result = parseDuration("abc");
    expect(result.ok).toBe(false);
  });
  it("不明な単位で ok: false を返す", () => {
    const result = parseDuration("1x");
    expect(result.ok).toBe(false);
  });
  it("負の数で ok: false を返す", () => {
    const result = parseDuration("-5m");
    expect(result.ok).toBe(false);
  });
  it("0s は ok: true で 0 を返す", () => {
    expect(parseDuration("0s")).toEqual({ ok: true, value: 0 });
  });
});
