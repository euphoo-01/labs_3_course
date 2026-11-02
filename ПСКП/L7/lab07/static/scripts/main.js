async function loadFile(format, url) {
  const status = document.getElementById(`${format}-status`);
  const output = document.getElementById(`${format}-output`);
  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const content = await response.text();
    if (format === 'json') JSON.parse(content);
    if (format === 'xml') {
      const documentXml = new DOMParser().parseFromString(content, 'application/xml');
      if (documentXml.querySelector('parsererror')) throw new Error('Некорректный XML');
    }
    output.textContent = content;
    status.textContent = 'Загружено';
    status.classList.add('success');
  } catch (error) {
    output.textContent = `Не удалось загрузить файл: ${error.message}`;
    status.textContent = 'Ошибка';
    status.classList.add('error');
  }
}

loadFile('json', '/data/example.json');
loadFile('xml', '/data/example.xml');
