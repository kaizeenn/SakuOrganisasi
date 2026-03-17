const CONFIG = {
  token: 'GANTI_DENGAN_TOKEN_RAHASIA',
  allowedSheets: [
    'accounts',
    'categories',
    'events',
    'members',
    'transactions',
    'cashLogs',
    'cashPeriods',
  ],
};

function doGet(e) {
  try {
    _authorize(e);

    const action = _param(e, 'action', 'list');
    if (action === 'health') {
      return _json({ ok: true, service: 'bendahara-sheets-api' });
    }

    if (action === 'list') {
      const sheetName = _requiredParam(e, 'sheet');
      const filters = _collectFilters(e);
      const rows = listRows(sheetName, filters);
      return _json({ ok: true, data: rows });
    }

    if (action === 'get') {
      const sheetName = _requiredParam(e, 'sheet');
      const id = _requiredParam(e, 'id');
      const row = getById(sheetName, id);
      return _json({ ok: true, data: row });
    }

    return _json({ ok: false, error: `Unknown action: ${action}` }, 400);
  } catch (error) {
    return _json({ ok: false, error: String(error) }, 500);
  }
}

function doPost(e) {
  try {
    _authorize(e);

    const payload = _parseBody(e);
    const action = payload.action || _param(e, 'action', 'create');

    if (action === 'create') {
      const sheetName = _required(payload.sheet, 'sheet wajib diisi');
      const data = _required(payload.data, 'data wajib diisi');
      const created = createRow(sheetName, data);
      return _json({ ok: true, data: created });
    }

    if (action === 'update') {
      const sheetName = _required(payload.sheet, 'sheet wajib diisi');
      const id = _required(payload.id, 'id wajib diisi');
      const data = _required(payload.data, 'data wajib diisi');
      const updated = updateRow(sheetName, id, data);
      return _json({ ok: true, data: updated });
    }

    if (action === 'delete') {
      const sheetName = _required(payload.sheet, 'sheet wajib diisi');
      const id = _required(payload.id, 'id wajib diisi');
      const mode = payload.mode || 'soft'; // soft | hard
      const result = deleteRow(sheetName, id, mode);
      return _json({ ok: true, data: result });
    }

    if (action === 'upsertBatch') {
      const sheetName = _required(payload.sheet, 'sheet wajib diisi');
      const rows = _required(payload.rows, 'rows wajib diisi');
      const result = upsertBatch(sheetName, rows);
      return _json({ ok: true, data: result });
    }

    return _json({ ok: false, error: `Unknown action: ${action}` }, 400);
  } catch (error) {
    return _json({ ok: false, error: String(error) }, 500);
  }
}

function listRows(sheetName, filters) {
  const sheet = _sheet(sheetName);
  const table = _readTable(sheet);

  return table.rows.filter((row) => {
    for (const key in filters) {
      if (String(row[key] ?? '') !== String(filters[key])) return false;
    }
    return true;
  });
}

function getById(sheetName, id) {
  const sheet = _sheet(sheetName);
  const table = _readTable(sheet);
  const row = table.rows.find((r) => String(r.id) === String(id));
  if (!row) throw new Error(`Data id=${id} tidak ditemukan di sheet ${sheetName}`);
  return row;
}

function createRow(sheetName, data) {
  const sheet = _sheet(sheetName);
  const table = _readTable(sheet);
  _ensureHeaderHasId(table.headers, sheet);

  const now = new Date().toISOString();
  const id = data.id != null ? String(data.id) : _nextId(table.rows);

  const rowData = { ...data, id };
  if ('updatedAt' in _headersMap(table.headers)) rowData.updatedAt = now;
  if ('createdAt' in _headersMap(table.headers) && !rowData.createdAt) {
    rowData.createdAt = now;
  }

  const values = table.headers.map((h) => _normalizeForCell(rowData[h]));
  sheet.appendRow(values);

  return getById(sheetName, id);
}

function updateRow(sheetName, id, patch) {
  const sheet = _sheet(sheetName);
  const table = _readTable(sheet);
  const rowIndex = table.rows.findIndex((r) => String(r.id) === String(id));
  if (rowIndex < 0) throw new Error(`Data id=${id} tidak ditemukan`);

  const target = { ...table.rows[rowIndex], ...patch };
  if ('updatedAt' in _headersMap(table.headers)) {
    target.updatedAt = new Date().toISOString();
  }

  const values = table.headers.map((h) => _normalizeForCell(target[h]));
  const sheetRow = rowIndex + 2;
  sheet.getRange(sheetRow, 1, 1, table.headers.length).setValues([values]);

  return getById(sheetName, id);
}

function deleteRow(sheetName, id, mode) {
  const sheet = _sheet(sheetName);
  const table = _readTable(sheet);
  const rowIndex = table.rows.findIndex((r) => String(r.id) === String(id));
  if (rowIndex < 0) throw new Error(`Data id=${id} tidak ditemukan`);

  if (mode === 'hard') {
    sheet.deleteRow(rowIndex + 2);
    return { id, deleted: true, mode: 'hard' };
  }

  const row = table.rows[rowIndex];
  const headers = table.headers;
  if (!headers.includes('deletedAt')) {
    throw new Error('Kolom deletedAt tidak tersedia untuk soft delete');
  }

  row.deletedAt = new Date().toISOString();
  if (headers.includes('updatedAt')) {
    row.updatedAt = new Date().toISOString();
  }

  const values = headers.map((h) => _normalizeForCell(row[h]));
  sheet.getRange(rowIndex + 2, 1, 1, headers.length).setValues([values]);

  return { id, deleted: true, mode: 'soft' };
}

function upsertBatch(sheetName, rows) {
  if (!Array.isArray(rows)) throw new Error('rows harus array');

  const sheet = _sheet(sheetName);
  const table = _readTable(sheet);
  _ensureHeaderHasId(table.headers, sheet);

  let created = 0;
  let updated = 0;

  rows.forEach((item) => {
    if (item == null || typeof item !== 'object') return;
    const id = item.id != null ? String(item.id) : null;

    if (!id) {
      createRow(sheetName, item);
      created++;
      return;
    }

    const exists = table.rows.find((r) => String(r.id) === id);
    if (exists) {
      updateRow(sheetName, id, item);
      updated++;
    } else {
      createRow(sheetName, item);
      created++;
    }
  });

  return { created, updated, total: rows.length };
}

function _sheet(sheetName) {
  if (!CONFIG.allowedSheets.includes(sheetName)) {
    throw new Error(`Sheet tidak diizinkan: ${sheetName}`);
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(sheetName);
  if (!sheet) throw new Error(`Sheet tidak ditemukan: ${sheetName}`);
  return sheet;
}

function _readTable(sheet) {
  const lastRow = sheet.getLastRow();
  const lastCol = sheet.getLastColumn();

  if (lastRow < 1 || lastCol < 1) {
    throw new Error(`Sheet ${sheet.getName()} kosong. Pastikan baris 1 adalah header.`);
  }

  const headers = sheet.getRange(1, 1, 1, lastCol).getValues()[0].map((h) => String(h).trim());
  if (!headers.includes('id')) {
    throw new Error(`Sheet ${sheet.getName()} wajib punya kolom id.`);
  }

  if (lastRow === 1) return { headers, rows: [] };

  const values = sheet.getRange(2, 1, lastRow - 1, lastCol).getValues();
  const rows = values.map((row) => {
    const obj = {};
    headers.forEach((h, i) => {
      obj[h] = row[i];
    });
    return obj;
  });

  return { headers, rows };
}

function _authorize(e) {
  const token = _param(e, 'token', '');
  if (token !== CONFIG.token) {
    throw new Error('Unauthorized: token tidak valid');
  }
}

function _parseBody(e) {
  if (!e || !e.postData || !e.postData.contents) {
    throw new Error('Body JSON tidak ditemukan');
  }

  let payload;
  try {
    payload = JSON.parse(e.postData.contents);
  } catch (_) {
    throw new Error('Body harus JSON valid');
  }

  if (!payload || typeof payload !== 'object') {
    throw new Error('Payload JSON tidak valid');
  }

  return payload;
}

function _collectFilters(e) {
  const params = (e && e.parameter) || {};
  const reserved = new Set(['action', 'sheet', 'id', 'token']);
  const filters = {};

  Object.keys(params).forEach((key) => {
    if (!reserved.has(key)) filters[key] = params[key];
  });

  return filters;
}

function _param(e, key, fallback) {
  const params = (e && e.parameter) || {};
  if (params[key] == null || params[key] === '') return fallback;
  return params[key];
}

function _requiredParam(e, key) {
  const value = _param(e, key, null);
  if (value == null) throw new Error(`Parameter ${key} wajib diisi`);
  return value;
}

function _required(value, message) {
  if (value == null) throw new Error(message);
  return value;
}

function _nextId(rows) {
  let max = 0;
  rows.forEach((row) => {
    const n = Number(row.id);
    if (Number.isFinite(n) && n > max) max = n;
  });
  return String(max + 1);
}

function _normalizeForCell(value) {
  if (value == null) return '';
  if (typeof value === 'object') return JSON.stringify(value);
  return value;
}

function _ensureHeaderHasId(headers, sheet) {
  if (headers.includes('id')) return;
  throw new Error(`Header sheet ${sheet.getName()} harus mengandung kolom id.`);
}

function _headersMap(headers) {
  const map = {};
  headers.forEach((h) => {
    map[h] = true;
  });
  return map;
}

function _json(data, code) {
  const output = ContentService.createTextOutput(JSON.stringify(data));
  output.setMimeType(ContentService.MimeType.JSON);
  if (code && output.setResponseCode) {
    output.setResponseCode(code);
  }
  return output;
}
