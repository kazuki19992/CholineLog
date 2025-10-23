import { validateColinLog } from "./validator";
import { readFileSync } from "fs";

// コマンドライン引数からファイルパスを取得
const args = process.argv.slice(2);

if (args.length === 0) {
  console.error("Usage: npm start <json-file-path>");
  console.error("Example: npm start data/test.json");
  process.exit(1);
}

const filePath = args[0];

try {
  // JSONファイルを読み込み
  const fileContent = readFileSync(filePath!, "utf-8");
  const data = JSON.parse(fileContent);

  console.log(`Validating: ${filePath}`);

  if (validateColinLog(data)) {
    console.log("✓ Valid!");
    process.exit(0);
  } else {
    console.log("✗ Invalid");
    process.exit(1);
  }
} catch (error) {
  if (error instanceof Error) {
    console.error(`Error: ${error.message}`);
  }
  process.exit(1);
}
