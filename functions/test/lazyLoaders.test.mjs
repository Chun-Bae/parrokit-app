// 지연 로딩한 SDK가 실제로 불려 오는지 본다(5차).
//
// 맨 위 `import {WaveFile} from "wavefile"`은 컴파일러가 CommonJS 모듈을
// 맞춰 줬지만, `await import("wavefile")`은 날것이라 WaveFile이 default
// 밑에 있다. 그걸 놓쳐서 한 번 틀렸고, TTS를 실제로 돌려야만 터지는
// 자리라 빌드도 lint도 잡아 주지 못했다.
//
// 그래서 컴파일 결과에서 loader를 그대로 뽑아 돌려 본다. 새 지연 로딩을
// 더할 때 모양이 틀리면 여기서 걸린다.
//
// 실행: functions에서 `node --test test/lazyLoaders.test.mjs`
import {test} from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";

const SOURCES = [
  "lib/contentStudioAi.js",
];

test("지연 로딩한 것이 모두 생성자로 나온다", async () => {
  let found = 0;
  for (const path of SOURCES) {
    const code = readFileSync(path, "utf8");
    const loaders = [...code.matchAll(/const (load\w+) = async \(\) => (.+?);\n/g)];
    for (const [, name, expr] of loaders) {
      found++;
      const value = await eval(`(async () => ${expr})()`);
      assert.equal(
        typeof value,
        "function",
        `${name}이(가) 생성자가 아니다 (${typeof value}). ` +
          "CommonJS 모듈이면 .default 밑을 봐야 한다."
      );
    }
  }
  assert.ok(found > 0, "loader를 하나도 못 찾았다 - 정규식이 낡았는지 본다");
});

test("무거운 SDK를 맨 위에서 불러오지 않는다", () => {
  const src = readFileSync("src/contentStudioAi.ts", "utf8");
  const head = src.slice(0, src.indexOf("const loadElevenLabs"));
  for (const pkg of [
    "@elevenlabs/elevenlabs-js",
    "@google-cloud/text-to-speech",
    "@google/genai",
    "wavefile",
    "@genkit-ai/firebase",
  ]) {
    assert.ok(
      !head.includes(`from "${pkg}"`),
      `${pkg}을(를) 맨 위에서 불러오고 있다. index.ts가 export *로 모으므로 ` +
        "광고 콜백 하나를 깨울 때도 전부 읽힌다."
    );
  }
});
