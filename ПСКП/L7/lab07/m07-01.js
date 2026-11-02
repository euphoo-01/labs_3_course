"use strict";

const fs = require("node:fs");
const path = require("node:path");

const mimeTypes = {
  ".html": "text/html",
  ".css": "text/css",
  ".js": "text/javascript",
  ".png": "image/png",
  ".docx": "application/msword",
  ".json": "application/json",
  ".xml": "application/xml",
  ".mp4": "video/mp4",
};

function isInside(root, file) {
  const relative = path.relative(root, file);
  return (
    relative !== "" &&
    relative !== ".." &&
    !relative.startsWith(`..${path.sep}`) &&
    !path.isAbsolute(relative)
  );
}

function configureStatic({ path: directory = "static/" } = {}) {
  const root = path.resolve(__dirname, directory);

  async function handleStatic(req, res) {
    if (req.method !== "GET") {
      res.writeHead(405, { Allow: "GET" });
      res.end();
      return;
    }

    try {
      const pathname = (req.url || "").split("?", 1)[0];
      if (!pathname.startsWith("/")) throw new Error("Invalid path");
      const parts = pathname.slice(1).split("/").map(decodeURIComponent);
      if (
        parts.some(
          (part) =>
            part === "." ||
            part === ".." ||
            part.includes("/") ||
            part.includes("\\") ||
            part.includes("\0"),
        )
      ) {
        throw new Error("Invalid path");
      }
      const file = path.resolve(root, ...parts);
      const type = mimeTypes[path.extname(file).toLowerCase()];
      if (!type || !isInside(root, file)) throw new Error("Unsupported path");

      const realRoot = await fs.promises.realpath(root);
      const realFile = await fs.promises.realpath(file);
      if (!isInside(realRoot, realFile)) throw new Error("Path outside root");
      const handle = await fs.promises.open(realFile, "r");
      let stats;
      try {
        stats = await handle.stat();
        if (!stats.isFile()) throw new Error("Not a file");
      } catch (error) {
        await handle.close();
        throw error;
      }

      res.writeHead(200, {
        "Content-Type": type,
        "Content-Length": stats.size,
      });
      const stream = handle.createReadStream();
      stream.on("error", () => res.destroy());
      res.on("close", () => stream.destroy());
      stream.pipe(res);
    } catch {
      if (!res.headersSent) {
        res.writeHead(404);
        res.end();
      } else {
        res.destroy();
      }
    }
  }

  return {
    createStaticHandler() {
      return handleStatic;
    },
  };
}

module.exports = configureStatic;
