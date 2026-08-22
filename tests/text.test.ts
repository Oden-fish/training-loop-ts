import { describe, expect, it } from "vitest";
import { slugify, truncate } from "../src/text";

describe("slugify", () => {
  it("空白と記号をハイフンにする", () => {
    expect(slugify("Hello, World!")).toBe("hello-world");
  });
  it("前後のハイフンを落とす", () => {
    expect(slugify("  --Hello--  ")).toBe("hello");
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
