import Ajv from "ajv";
import addFormats from "ajv-formats";
import schema from "./schemas/colinelog.schema.json";

const ajv = new Ajv({ allErrors: true });
addFormats(ajv);

const validate = ajv.compile(schema);

export function validateColinLog(data: unknown): boolean {
  const valid = validate(data);

  if (!valid) {
    console.error("Validation errors:");
    validate.errors?.forEach((error) => {
      console.error(`  ${error.instancePath}: ${error.message}`);
    });
    return false;
  }

  return true;
}
