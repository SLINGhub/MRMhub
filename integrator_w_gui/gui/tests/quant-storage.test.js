import { formatStorageBytes } from "../ui/quant/storage.js";
Deno.test("QUANT storage sizes have readable decimal units and preserve zero", () => {
  for (const [bytes, expected] of [[0,"0 B"],[999,"999 B"],[1000,"1.0 KB"],[2_450_000,"2.5 MB"],[12_000_000_000,"12 GB"],[1_000_000_000_000,"1.0 TB"]]) {
    if (formatStorageBytes(bytes) !== expected) throw Error(`${bytes}: ${formatStorageBytes(bytes)} != ${expected}`);
  }
});
Deno.test("QUANT storage never presents invalid sizes as zero or a fake amount", () => {
  for (const value of [undefined, null, NaN, Infinity, -1]) {
    if (formatStorageBytes(value) !== "Unavailable") throw Error(`Invalid size accepted: ${value}`);
  }
});
