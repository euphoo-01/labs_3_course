const http = require("http");
const fs = require("fs");
const path = require("path");
const req = http.get("http://localhost:3000/09-08", (res) => {
  console.log("Статус:", res.statusCode);
  const output = fs.createWriteStream(
    path.join(__dirname, "DownloadedFile.txt"),
  );
  res.pipe(output);
  output.on("finish", () => console.log("Файл сохранен: DownloadedFile.txt"));
});
req.on("error", console.error);
