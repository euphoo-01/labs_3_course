const http = require("http");
const fs = require("fs");
const path = require("path");
const boundary = "----PSKPLab09Boundary";
const file = fs.readFileSync(path.join(__dirname, "MyFile.txt"));
const body = Buffer.concat([
  Buffer.from(
    `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="MyFile.txt"\r\nContent-Type: text/plain\r\n\r\n`,
  ),
  file,
  Buffer.from(`\r\n--${boundary}--\r\n`),
]);
const req = http.request(
  "http://localhost:3000/09-06",
  {
    method: "POST",
    headers: {
      "Content-Type": `multipart/form-data; boundary=${boundary}`,
      "Content-Length": body.length,
    },
  },
  (res) => {
    console.log("Статус:", res.statusCode);
    res.setEncoding("utf8");
    res.pipe(process.stdout);
  },
);
req.on("error", console.error);
req.end(body);
