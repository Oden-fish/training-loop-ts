import { describe, expect, it } from "vitest";
import { slugify } from "../src/text";

describe("slugify", () => {
  it("空白と記号をハイフンにする", () => {
    expect(slugify("Hello, World!")).toBe("hello-world");
  });
  it("前後のハイフンを落とす", () => {
    expect(slugify("  --Hello--  ")).toBe("hello");
  });
});
