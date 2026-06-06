const express = require('express');
const http = require('http');
const { WebSocketServer } = require('ws');
const Database = require('better-sqlite3');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

// Load .env
try {
  const envPath = path.join(__dirname, '.env');
  if (fs.existsSync(envPath)) {
    const lines = fs.readFileSync(envPath, 'utf8').split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith('#')) {
        const eqIdx = trimmed.indexOf('=');
        if (eqIdx > 0) {
          process.env[trimmed.slice(0, eqIdx).trim()] = trimmed.slice(eqIdx + 1).trim();
        }
      }
    }
  }
} catch (e) {}

const PORT = 4000;
const UPLOAD_DIR = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

// ─── Cloudflare R2 Upload via API ──────────────────────────────
const R2_CF_ACCOUNT_ID = process.env.R2_CF_ACCOUNT_ID || 'd36e604911c9089faece20fa04af46c3';
const R2_CF_API_TOKEN = process.env.R2_CF_API_TOKEN;
const R2_BUCKET = process.env.R2_BUCKET || 'neoant-files';
const useR2 = !!(R2_CF_API_TOKEN);

let r2PublicBase;

if (useR2) {
  r2PublicBase = process.env.R2_PUBLIC_DOMAIN
    ? `https://${process.env.R2_PUBLIC_DOMAIN}`
    : `https://pub-${process.env.R2_ACCOUNT_ID || 'c95b85e05db9db625c80e0bbce773cdf'}.r2.dev`;
  console.log(`R2: enabled (api, bucket=${R2_BUCKET}, public=${r2PublicBase})`);
} else {
  console.log('R2: disabled (missing R2_CF_API_TOKEN), using local fallback');
}

/**
 * Upload a file to Cloudflare R2 via API
 */
async function uploadToR2(filePath, originalName) {
  if (useR2) {
    try {
      const ext = path.extname(originalName) || '.bin';
      const key = `neoant/${uuidv4()}${ext}`;
      const ct = ext=='.jpg'||ext=='.jpeg'?'image/jpeg':ext=='.png'?'image/png':ext=='.gif'?'image/gif':ext=='.webp'?'image/webp':ext=='.mp4'?'video/mp4':ext=='.ogg'?'audio/ogg':ext=='.mp3'?'audio/mpeg':ext=='.pdf'?'application/pdf':'application/octet-stream';

      const body = await fs.promises.readFile(filePath);
      const url = `https://api.cloudflare.com/client/v4/accounts/${R2_CF_ACCOUNT_ID}/r2/buckets/${R2_BUCKET}/objects/${encodeURIComponent(key)}`;
      const res = await fetch(url, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${R2_CF_API_TOKEN}`,
          'Content-Type': ct,
        },
        body,
      });
      const result = await res.json();
      if (!result.success) {
        throw new Error(result.errors?.[0]?.message || 'R2 API error');
      }
      fs.unlink(filePath, () => {});
      return `${r2PublicBase}/${key}`;
    } catch(e) {
      console.error('R2 upload failed:', e.message);
    }
  }
  // Local fallback
  const ext = path.extname(originalName) || '.bin';
  const localName = `${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`;
  const dest = path.join(UPLOAD_DIR, localName);
  try { fs.renameSync(filePath, dest); } catch(e) { fs.copyFileSync(filePath, dest); fs.unlinkSync(filePath); }
  return `/uploads/${localName}`;
}

// ─── Database ──────────────────────────────────────────────
const dbPath = path.join(__dirname, 'neoant.db');
const db = new Database(dbPath);
db.pragma('journal_mode = WAL');
db.pragma('busy_timeout = 5000');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    unique_id TEXT UNIQUE,
    username TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    password TEXT NOT NULL,
    phone TEXT DEFAULT '',
    role TEXT DEFAULT 'user',
    avatar TEXT DEFAULT '',
    status TEXT DEFAULT '在线',
    created_at TEXT DEFAULT (datetime('now'))
  );
  CREATE TABLE IF NOT EXISTS invite_codes (
    id TEXT PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    created_by TEXT NOT NULL,
    max_uses INTEGER DEFAULT 1,
    used_count INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (created_by) REFERENCES users(id)
  );
  CREATE TABLE IF NOT EXISTS conversations (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    is_group INTEGER DEFAULT 0,
    avatar TEXT DEFAULT '',
    created_at TEXT DEFAULT (datetime('now'))
  );
  CREATE TABLE IF NOT EXISTS conversation_members (
    conversation_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    PRIMARY KEY (conversation_id, user_id),
    FOREIGN KEY (conversation_id) REFERENCES conversations(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
  );
  CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL,
    sender_id TEXT NOT NULL,
    text TEXT DEFAULT '',
    type TEXT DEFAULT 'text',
    file_url TEXT DEFAULT '',
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (conversation_id) REFERENCES conversations(id),
    FOREIGN KEY (sender_id) REFERENCES users(id)
  );
  CREATE TABLE IF NOT EXISTS contacts (
    user_id TEXT NOT NULL,
    contact_id TEXT NOT NULL,
    remark TEXT DEFAULT '',
    created_at TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, contact_id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (contact_id) REFERENCES users(id)
  );
  CREATE TABLE IF NOT EXISTS favorites (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    message_id TEXT NOT NULL,
    conversation_id TEXT NOT NULL,
    text TEXT DEFAULT '',
    sender_name TEXT DEFAULT '',
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id)
  );
  CREATE TABLE IF NOT EXISTS drafts (
    user_id TEXT NOT NULL,
    conversation_id TEXT NOT NULL,
    content TEXT DEFAULT '',
    updated_at TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, conversation_id),
    FOREIGN KEY (user_id) REFERENCES users(id)
  );
  CREATE TABLE IF NOT EXISTS user_settings (
    user_id TEXT PRIMARY KEY,
    notify_new_msg INTEGER DEFAULT 1,
    notify_sound INTEGER DEFAULT 1,
    notify_vibrate INTEGER DEFAULT 1,
    notify_preview INTEGER DEFAULT 1,
    privacy_online INTEGER DEFAULT 1,
    privacy_read_receipt INTEGER DEFAULT 1,
    chat_background TEXT DEFAULT '',
    FOREIGN KEY (user_id) REFERENCES users(id)
  );
  CREATE TABLE IF NOT EXISTS id_counter (
    name TEXT PRIMARY KEY,
    next_id INTEGER NOT NULL DEFAULT 1
  );
  CREATE TABLE IF NOT EXISTS sessions (
    token TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id)
  );
`);

// Clean expired sessions (older than 30 days)
db.exec("DELETE FROM sessions WHERE created_at < datetime('now', '-30 days')");

// Helper: generate unique_id (atomic counter)
function generateUniqueId() {
  const id = db.transaction(() => {
    let row = db.prepare("SELECT next_id FROM id_counter WHERE name = 'user_uid'").get();
    if (!row) {
      db.prepare("INSERT INTO id_counter (name, next_id) VALUES ('user_uid', 2)").run();
      return 1;
    }
    db.prepare("UPDATE id_counter SET next_id = next_id + 1 WHERE name = 'user_uid'").run();
    return row.next_id;
  })();
  return String(id).padStart(7, '0');
}

// Assign/regenerate unique_id for all users (7-digit format)
const allUsers = db.prepare('SELECT id FROM users ORDER BY rowid').all();
for (let i = 0; i < allUsers.length; i++) {
  const uid = String(i + 1).padStart(7, '0');
  db.prepare('UPDATE users SET unique_id = ? WHERE id = ?').run(uid, allUsers[i].id);
}
db.prepare("DELETE FROM id_counter WHERE name = 'user_uid'").run();
let maxUid = db.prepare('SELECT MAX(CAST(unique_id AS INTEGER)) as m FROM users').get().m || allUsers.length;
db.prepare("INSERT OR REPLACE INTO id_counter (name, next_id) VALUES ('user_uid', ?)").run(maxUid + 1);

// Ensure notify_preview column exists in user_settings (migration)
const tableInfo = db.prepare("PRAGMA table_info('user_settings')").all();
if (!tableInfo.some(col => col.name === 'notify_preview')) {
  db.exec("ALTER TABLE user_settings ADD COLUMN notify_preview INTEGER DEFAULT 1");
}

// ─── Auth Middleware ──────────────────────────────────────────
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: '未登录' });
  }
  const token = authHeader.slice(7);
  const session = db.prepare('SELECT user_id FROM sessions WHERE token = ?').get(token);
  if (!session) {
    return res.status(401).json({ error: '登录已过期，请重新登录' });
  }
  req.userId = session.user_id;
  next();
}

// Helper: strip HTML tags
function stripHtml(str) {
  if (!str) return str;
  return str.replace(/<[^>]*>/g, '');
}

// Helper: generate session token
function generateToken() {
  return crypto.randomBytes(32).toString('hex');
}

// Seed demo users
const seedUsers = [
  { username: 'demo', name: '用户', password: '123456', role: 'user' },
  { username: 'test', name: '测试', password: '123456', role: 'user' },
  { username: 'admin', name: '管理员', password: 'admin123', role: 'admin' },
  { username: 'chenming', name: '陈明', password: '123456', role: 'user' },
  { username: 'lihua', name: '李华', password: '123456', role: 'user' },
  { username: 'zhangwei', name: '张伟', password: '123456', role: 'user' },
  { username: 'wangfang', name: '王芳', password: '123456', role: 'user' },
  { username: 'liuting', name: '刘婷', password: '123456', role: 'user' },
  { username: 'wanglei', name: '王磊', password: '123456', role: 'user' },
  { username: 'zhaoqiang', name: '赵强', password: '123456', role: 'user' },
];
for (const u of seedUsers) {
  const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(u.username);
  if (!existing) {
    const id = uuidv4();
    const hash = bcrypt.hashSync(u.password, 10);
    const uniqueId = generateUniqueId();
    db.prepare('INSERT INTO users (id, unique_id, username, name, password, role) VALUES (?, ?, ?, ?, ?, ?)').run(id, uniqueId, u.username, u.name, hash, u.role);
  } else {
    db.prepare('UPDATE users SET role = ? WHERE username = ? AND role IS NULL').run(u.role, u.username);
  }
}

// Seed conversations & messages
if (db.prepare('SELECT COUNT(*) as c FROM conversations').get().c === 0) {
  const demo = db.prepare("SELECT id, name FROM users WHERE username='demo'").get();
  const makeMsg = (convId, senderUsername, text, minutesAgo) => ({
    id: uuidv4(), conversation_id: convId,
    sender_id: db.prepare("SELECT id FROM users WHERE username=?").get(senderUsername).id,
    text, created_at: new Date(Date.now() - minutesAgo * 60000).toISOString()
  });
  const msgs = [];

  const convCm = uuidv4();
  db.prepare('INSERT INTO conversations (id, name) VALUES (?, ?)').run(convCm, '陈明');
  db.prepare('INSERT INTO conversation_members VALUES (?, ?)').run(convCm, demo.id);
  const cmId = db.prepare("SELECT id FROM users WHERE username='chenming'").get().id;
  db.prepare('INSERT INTO conversation_members VALUES (?, ?)').run(convCm, cmId);
  msgs.push(makeMsg(convCm, 'chenming', '你好！最近项目进展怎么样？', 30));
  msgs.push(makeMsg(convCm, 'demo', '挺好的，前端联调基本完成了', 28));
  msgs.push(makeMsg(convCm, 'chenming', '用户列表接口的问题确认了吗？', 25));
  msgs.push(makeMsg(convCm, 'demo', '确认了，用 page/pageSize 参数', 23));

  const convLh = uuidv4();
  db.prepare('INSERT INTO conversations (id, name) VALUES (?, ?)').run(convLh, '李华');
  db.prepare('INSERT INTO conversation_members VALUES (?, ?)').run(convLh, demo.id);
  const lhId = db.prepare("SELECT id FROM users WHERE username='lihua'").get().id;
  db.prepare('INSERT INTO conversation_members VALUES (?, ?)').run(convLh, lhId);
  msgs.push(makeMsg(convLh, 'lihua', '收到，谢谢！', 120));
  msgs.push(makeMsg(convLh, 'demo', '好的，明天见', 118));

  const convZw = uuidv4();
  db.prepare('INSERT INTO conversations (id, name) VALUES (?, ?)').run(convZw, '张伟');
  db.prepare('INSERT INTO conversation_members VALUES (?, ?)').run(convZw, demo.id);
  const zwId = db.prepare("SELECT id FROM users WHERE username='zhangwei'").get().id;
  db.prepare('INSERT INTO conversation_members VALUES (?, ?)').run(convZw, zwId);
  msgs.push(makeMsg(convZw, 'zhangwei', '会议纪要已发邮件', 180));

  const convWf = uuidv4();
  db.prepare('INSERT INTO conversations (id, name) VALUES (?, ?)').run(convWf, '王芳');
  db.prepare('INSERT INTO conversation_members VALUES (?, ?)').run(convWf, demo.id);
  const wfId = db.prepare("SELECT id FROM users WHERE username='wangfang'").get().id;
  db.prepare('INSERT INTO conversation_members VALUES (?, ?)').run(convWf, wfId);
  msgs.push(makeMsg(convWf, 'wangfang', '周末有空吗？', 360));

  const convGrp = uuidv4();
  db.prepare('INSERT INTO conversations (id, name, is_group) VALUES (?, ?, 1)').run(convGrp, '项目A-需求讨论');
  db.prepare('INSERT INTO conversation_members VALUES (?, ?)').run(convGrp, demo.id);
  for (const username of ['chenming', 'lihua', 'zhangwei', 'liuting']) {
    const uid = db.prepare("SELECT id FROM users WHERE username=?").get(username).id;
    db.prepare('INSERT INTO conversation_members VALUES (?, ?)').run(convGrp, uid);
  }

  const insertMsg = db.prepare('INSERT INTO messages (id, conversation_id, sender_id, text, created_at) VALUES (?, ?, ?, ?, ?)');
  for (const m of msgs) insertMsg.run(m.id, m.conversation_id, m.sender_id, m.text, m.created_at);

  const insertContact = db.prepare('INSERT INTO contacts (user_id, contact_id) VALUES (?, ?)');
  for (const username of ['chenming', 'lihua', 'zhangwei', 'wangfang', 'liuting', 'wanglei', 'zhaoqiang']) {
    const cid = db.prepare("SELECT id FROM users WHERE username=?").get(username).id;
    insertContact.run(demo.id, cid);
    insertContact.run(cid, demo.id);
  }
}

// ─── HTTP Server ───────────────────────────────────────────────
const app = express();
app.use(cors());
app.use(express.json({ limit: '5mb' }));

const storage = multer.diskStorage({
  destination: UPLOAD_DIR,
  filename: (req, file, cb) => cb(null, `${Date.now()}-${file.originalname}`),
});
const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } });

// ─── Auth Routes (no token required) ──────────────────────────

app.post('/api/auth/register', (req, res) => {
  const { username, name, password, phone, inviteCode } = req.body;
  if ((!username || !username.trim()) && (!phone || !phone.trim())) return res.status(400).json({ error: '账号或手机号必填' });
  if (!name || !name.trim()) return res.status(400).json({ error: '昵称必填' });
  if (!password) return res.status(400).json({ error: '密码必填' });

  // Validate invite code
  if (!inviteCode) return res.status(400).json({ error: '需要邀请码才能注册' });
  const inv = db.prepare('SELECT * FROM invite_codes WHERE code = ?').get(inviteCode);
  if (!inv) return res.status(400).json({ error: '邀请码无效' });
  if (inv.used_count >= inv.max_uses) return res.status(400).json({ error: '邀请码已用完' });

  const displayName = stripHtml(name || username);
  const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
  if (existing) return res.status(400).json({ error: '账号已存在' });
  if (phone) {
    const phoneExists = db.prepare('SELECT id FROM users WHERE phone = ? AND phone != ?').get(phone, '');
    if (phoneExists) return res.status(400).json({ error: '手机号已被注册' });
  }

  const id = uuidv4();
  const hash = bcrypt.hashSync(password, 10);
  const uniqueId = generateUniqueId();
  db.prepare('INSERT INTO users (id, unique_id, username, name, password, phone) VALUES (?, ?, ?, ?, ?, ?)').run(id, uniqueId, username, displayName, hash, phone || '');
  db.prepare('UPDATE invite_codes SET used_count = used_count + 1 WHERE id = ?').run(inv.id);
  db.prepare('INSERT OR IGNORE INTO user_settings (user_id) VALUES (?)').run(id);

  // Generate token
  const token = generateToken();
  db.prepare('INSERT INTO sessions (token, user_id) VALUES (?, ?)').run(token, id);

  res.json({
    ok: true,
    token,
    user: { id, unique_id: uniqueId, username, name: displayName, phone: phone || '', role: 'user' }
  });
});

app.post('/api/auth/login', (req, res) => {
  const { username, password } = req.body;
  const user = db.prepare('SELECT * FROM users WHERE username = ?').get(username);
  if (!user) return res.status(401).json({ error: '账号不存在' });
  if (!bcrypt.compareSync(password, user.password)) return res.status(401).json({ error: '密码错误' });
  db.prepare('INSERT OR IGNORE INTO user_settings (user_id) VALUES (?)').run(user.id);

  // Generate token
  const token = generateToken();
  db.prepare('INSERT INTO sessions (token, user_id) VALUES (?, ?)').run(token, user.id);

  res.json({
    ok: true,
    token,
    user: { id: user.id, unique_id: user.unique_id, username: user.username, name: user.name, phone: user.phone, role: user.role, avatar: user.avatar, status: user.status }
  });
});

// ─── Protected Routes ─────────────────────────────────────────

// Users
app.get('/api/users/:id', (req, res) => {
  const user = db.prepare('SELECT id, unique_id, username, name, phone, role, avatar, status FROM users WHERE id = ?').get(req.params.id);
  if (!user) return res.status(404).json({ error: '用户不存在' });
  res.json(user);
});

// Conversations
app.get('/api/conversations/:userId', (req, res) => {
  const convs = db.prepare(`
    SELECT c.*,
      (SELECT m.text FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message,
      (SELECT m.created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_time,
      (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id AND m.created_at > ?) as unread,
      (SELECT u.id FROM conversation_members cm2 JOIN users u ON u.id = cm2.user_id WHERE cm2.conversation_id = c.id AND cm2.user_id != ? LIMIT 1) as target_user_id
    FROM conversations c
    JOIN conversation_members cm ON cm.conversation_id = c.id
    WHERE cm.user_id = ?
    ORDER BY last_time DESC
  `).all(new Date(0).toISOString(), req.params.userId, req.params.userId);
  res.json(convs);
});

// Messages (read)
app.get('/api/messages/:conversationId', (req, res) => {
  const msgs = db.prepare(`
    SELECT m.*, u.name as sender_name, u.avatar as sender_avatar
    FROM messages m JOIN users u ON u.id = m.sender_id
    WHERE m.conversation_id = ?
    ORDER BY m.created_at ASC
    LIMIT 200
  `).all(req.params.conversationId);
  res.json(msgs);
});

// Messages (write) — uses authenticated userId from token, NOT from body
app.post('/api/messages', authMiddleware, upload.single('file'), async (req, res) => {
  const { conversation_id, text, type } = req.body;
  const sender_id = req.userId; // FROM TOKEN — prevents forgery

  if (!text || !text.trim()) return res.status(400).json({ error: '消息内容不能为空' });

  const id = uuidv4();
  let fileUrl = '';
  if (req.file) {
    try {
      fileUrl = await uploadToR2(req.file.path, req.file.originalname);
    } catch (e) {
      fileUrl = `/uploads/${req.file.filename}`;
      console.error('File server upload failed, local fallback:', e.message);
    }
  }
  db.prepare('INSERT INTO messages (id, conversation_id, sender_id, text, type, file_url) VALUES (?, ?, ?, ?, ?, ?)')
    .run(id, conversation_id, sender_id, stripHtml(text || ''), type || 'text', fileUrl);
  const msg = db.prepare(`
    SELECT m.*, u.name as sender_name, u.avatar as sender_avatar
    FROM messages m JOIN users u ON u.id = m.sender_id
    WHERE m.id = ?
  `).get(id);
  // Broadcast to all conversation members via WebSocket
  if (msg) {
    const members = db.prepare('SELECT user_id FROM conversation_members WHERE conversation_id = ?').all(conversation_id);
    for (const m of members) {
      const clients = wsClients.get(m.user_id);
      if (clients) clients.forEach(c => { try { c.send(JSON.stringify(msg)); } catch {} });
    }
  }
  res.json(msg);
});

// File upload (general purpose)
// Artifact upload endpoint for CI
app.post('/api/upload-artifact', (req, res) => {
  const filename = req.headers['x-filename'] || `artifact-${Date.now()}`;
  const targetDir = '/var/www/html/neoant_packages';
  if (!fs.existsSync(targetDir)) fs.mkdirSync(targetDir, { recursive: true });
  const targetPath = path.join(targetDir, filename);
  const ws = fs.createWriteStream(targetPath);
  req.on('data', (chunk) => ws.write(chunk));
  req.on('end', () => {
    ws.end();
    res.json({ ok: true, url: `https://dipsin.com:8098/${filename}` });
  });
  req.on('error', () => {
    ws.end();
    res.status(500).json({ error: 'Upload failed' });
  });
});

app.post('/api/upload', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: '未选择文件' });
  try {
    const url = await uploadToR2(req.file.path, req.file.originalname);
    res.json({ url, name: req.file.originalname, size: req.file.size });
  } catch (e) {
    const url = `/uploads/${req.file.filename}`;
    console.error('File server upload failed for /api/upload, local fallback:', e.message);
    res.json({ url, name: req.file.originalname, size: req.file.size });
  }
});

// Contacts
app.get('/api/contacts/:userId', (req, res) => {
  const contacts = db.prepare(`
    SELECT u.id, u.unique_id, u.username, u.name, u.phone, u.role, u.avatar, u.status
    FROM contacts c JOIN users u ON u.id = c.contact_id
    WHERE c.user_id = ?
  `).all(req.params.userId);
  res.json(contacts);
});

app.post('/api/contacts/add', authMiddleware, (req, res) => {
  const { contactUsername, contactPhone, remark } = req.body;
  const userId = req.userId; // FROM TOKEN
  let contact;
  if (contactUsername) {
    contact = db.prepare('SELECT id FROM users WHERE username = ?').get(contactUsername);
  } else if (contactPhone) {
    contact = db.prepare('SELECT id FROM users WHERE phone = ?').get(contactPhone);
  }
  if (!contact) return res.status(404).json({ error: '用户不存在' });
  const contactUser = db.prepare('SELECT id, name FROM users WHERE id = ?').get(contact.id);
  try {
    db.prepare('INSERT INTO contacts (user_id, contact_id, remark) VALUES (?, ?, ?)').run(userId, contact.id, remark || '');
    db.prepare('INSERT INTO contacts (user_id, contact_id) VALUES (?, ?)').run(contact.id, userId);
    // Notify via WebSocket
    const requester = db.prepare('SELECT name FROM users WHERE id = ?').get(userId);
    const clients = wsClients.get(contact.id);
    if (clients) {
      clients.forEach(c => { try { c.send(JSON.stringify({ type: 'contact:added', from_id: userId, from_name: requester?.name || '' })); } catch {} });
    }
    res.json({ ok: true });
  } catch { res.status(400).json({ error: '已经是好友了' }); }
});

app.post('/api/contacts/remove', authMiddleware, (req, res) => {
  const { contactName } = req.body;
  const userId = req.userId;
  const contact = db.prepare('SELECT id FROM users WHERE name = ?').get(contactName);
  if (!contact) return res.status(404).json({ error: '联系人不存在' });
  db.prepare('DELETE FROM contacts WHERE user_id = ? AND contact_id = ?').run(userId, contact.id);
  db.prepare('DELETE FROM contacts WHERE user_id = ? AND contact_id = ?').run(contact.id, userId);
  res.json({ ok: true });
});

// Search
app.get('/api/search/users', (req, res) => {
  const q = (req.query.q || '').replace(/%/g, '\\%').replace(/_/g, '\\_');
  const users = db.prepare("SELECT id, unique_id, username, name, phone, role, avatar, status FROM users WHERE name LIKE ? ESCAPE '\\' OR username LIKE ? ESCAPE '\\' OR phone LIKE ? ESCAPE '\\' LIMIT 20")
    .all(`%${q}%`, `%${q}%`, `%${q}%`);
  res.json(users);
});

app.get('/api/search/messages/:userId', (req, res) => {
  const q = (req.query.q || '').replace(/%/g, '\\%').replace(/_/g, '\\_');
  const msgs = db.prepare(`
    SELECT m.*, u.name as sender_name, c.name as conversation_name
    FROM messages m
    JOIN conversations c ON c.id = m.conversation_id
    JOIN users u ON u.id = m.sender_id
    JOIN conversation_members cm ON cm.conversation_id = m.conversation_id
    WHERE cm.user_id = ? AND m.text LIKE ? ESCAPE '\\'
    ORDER BY m.created_at DESC LIMIT 50
  `).all(req.params.userId, `%${q}%`);
  res.json(msgs);
});

// Update profile
app.post('/api/profile/update', authMiddleware, (req, res) => {
  const { name, avatar, phone } = req.body;
  const userId = req.userId; // FROM TOKEN
  db.prepare('UPDATE users SET name = COALESCE(?, name), avatar = COALESCE(?, avatar), phone = COALESCE(?, phone) WHERE id = ?')
    .run(name ? stripHtml(name) : null, avatar, phone, userId);
  res.json({ ok: true });
});

// Invite Codes
app.post('/api/invite/generate', authMiddleware, (req, res) => {
  const { count } = req.body;
  const userId = req.userId;
  const user = db.prepare('SELECT role FROM users WHERE id = ?').get(userId);
  if (!user || user.role !== 'admin') return res.status(403).json({ error: '只有管理员可以生成邀请码' });

  const num = Math.min(count || 1, 100);
  const codes = [];
  for (let i = 0; i < num; i++) {
    let code;
    do {
      code = String(Math.floor(100000 + Math.random() * 900000));
    } while (db.prepare('SELECT id FROM invite_codes WHERE code = ?').get(code));
    const id = uuidv4();
    db.prepare('INSERT INTO invite_codes (id, code, created_by) VALUES (?, ?, ?)').run(id, code, userId);
    codes.push(code);
  }
  res.json({ ok: true, codes });
});

app.get('/api/invite/list', (req, res) => {
  const { userId } = req.query;
  const user = db.prepare('SELECT role FROM users WHERE id = ?').get(userId);
  if (!user || user.role !== 'admin') return res.status(403).json({ error: '仅限管理员' });
  const codes = db.prepare(`
    SELECT ic.*, u.name as creator_name
    FROM invite_codes ic JOIN users u ON u.id = ic.created_by
    ORDER BY ic.created_at DESC LIMIT 200
  `).all();
  res.json(codes);
});

// Favorites
app.get('/api/favorites/:userId', (req, res) => {
  const favs = db.prepare('SELECT * FROM favorites WHERE user_id = ? ORDER BY created_at DESC LIMIT 100')
    .all(req.params.userId);
  res.json({ favorites: favs });
});

app.post('/api/favorites/add', authMiddleware, (req, res) => {
  const { messageId, conversationId, text, senderName } = req.body;
  const userId = req.userId;
  const id = uuidv4();
  db.prepare('INSERT INTO favorites (id, user_id, message_id, conversation_id, text, sender_name) VALUES (?, ?, ?, ?, ?, ?)')
    .run(id, userId, messageId, conversationId, text || '', senderName || '');
  res.json({ ok: true, id });
});

app.post('/api/favorites/remove', authMiddleware, (req, res) => {
  const { id } = req.body;
  db.prepare('DELETE FROM favorites WHERE id = ?').run(id);
  res.json({ ok: true });
});

// Drafts
app.get('/api/drafts/:userId/:conversationId', (req, res) => {
  const draft = db.prepare('SELECT content FROM drafts WHERE user_id = ? AND conversation_id = ?')
    .get(req.params.userId, req.params.conversationId);
  res.json({ content: draft ? draft.content : '' });
});

app.post('/api/drafts/save', authMiddleware, (req, res) => {
  const { conversationId, content } = req.body;
  const userId = req.userId;
  if ((content || '').trim()) {
    db.prepare('INSERT OR REPLACE INTO drafts (user_id, conversation_id, content, updated_at) VALUES (?, ?, ?, datetime(\'now\'))')
      .run(userId, conversationId, content);
  } else {
    db.prepare('DELETE FROM drafts WHERE user_id = ? AND conversation_id = ?').run(userId, conversationId);
  }
  res.json({ ok: true });
});

// Forward Message
app.post('/api/messages/forward', authMiddleware, (req, res) => {
  const { targetConversationId, originalText, originalType, originalFileUrl } = req.body;
  const senderId = req.userId;
  const id = uuidv4();
  db.prepare('INSERT INTO messages (id, conversation_id, sender_id, text, type, file_url) VALUES (?, ?, ?, ?, ?, ?)')
    .run(id, targetConversationId, senderId, originalText || '', originalType || 'text', originalFileUrl || '');
  const msg = db.prepare(`
    SELECT m.*, u.name as sender_name, u.avatar as sender_avatar
    FROM messages m JOIN users u ON u.id = m.sender_id WHERE m.id = ?
  `).get(id);
  res.json(msg);
});

// Delete Message
app.post('/api/messages/delete', authMiddleware, (req, res) => {
  const { messageId, conversationId } = req.body;
  if (!messageId) return res.status(400).json({ error: '消息ID必填' });
  // Verify the message belongs to the authenticated user
  const msg = db.prepare('SELECT sender_id FROM messages WHERE id = ?').get(messageId);
  if (!msg) return res.status(404).json({ error: '消息不存在' });
  if (msg.sender_id !== req.userId) return res.status(403).json({ error: '只能删除自己的消息' });
  db.prepare('DELETE FROM messages WHERE id = ?').run(messageId);
  if (conversationId) {
    const members = db.prepare('SELECT user_id FROM conversation_members WHERE conversation_id = ?').all(conversationId);
    for (const m of members) {
      const clients = wsClients.get(m.user_id);
      if (clients) {
        clients.forEach(c => { try { c.send(JSON.stringify({ type: 'message:deleted', message_id: messageId, conversation_id: conversationId })); } catch {} });
      }
    }
  }
  res.json({ ok: true });
});

// Group Management
app.get('/api/groups/:groupId/members', (req, res) => {
  const members = db.prepare(`
    SELECT u.id, u.username, u.name, u.avatar, u.status
    FROM conversation_members cm JOIN users u ON u.id = cm.user_id
    WHERE cm.conversation_id = ?
  `).all(req.params.groupId);
  res.json(members);
});

app.post('/api/groups/:groupId/invite', authMiddleware, (req, res) => {
  const { memberUsername } = req.body;
  const member = db.prepare('SELECT id, name FROM users WHERE username = ?').get(memberUsername);
  if (!member) return res.status(404).json({ error: '用户不存在' });
  try {
    db.prepare('INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?)').run(req.params.groupId, member.id);
    res.json({ ok: true, member });
  } catch { res.status(400).json({ error: '已经在群里了' }); }
});

app.post('/api/groups/:groupId/remove', authMiddleware, (req, res) => {
  const { memberId } = req.body;
  db.prepare('DELETE FROM conversation_members WHERE conversation_id = ? AND user_id = ?')
    .run(req.params.groupId, memberId);
  res.json({ ok: true });
});

app.post('/api/groups/:groupId/update', authMiddleware, (req, res) => {
  const { name, avatar } = req.body;
  db.prepare('UPDATE conversations SET name = COALESCE(?, name), avatar = COALESCE(?, avatar) WHERE id = ?')
    .run(name ? stripHtml(name) : null, avatar, req.params.groupId);
  res.json({ ok: true });
});

// User Settings
app.get('/api/settings/:userId', (req, res) => {
  let settings = db.prepare('SELECT * FROM user_settings WHERE user_id = ?').get(req.params.userId);
  if (!settings) {
    db.prepare('INSERT INTO user_settings (user_id) VALUES (?)').run(req.params.userId);
    settings = db.prepare('SELECT * FROM user_settings WHERE user_id = ?').get(req.params.userId);
  }
  res.json(settings);
});

app.post('/api/settings/update', authMiddleware, (req, res) => {
  const { ...updates } = req.body;
  const userId = req.userId;
  const allowed = ['notify_new_msg','notify_sound','notify_vibrate','notify_preview','privacy_online','privacy_read_receipt','chat_background'];
  const sets = Object.entries(updates)
    .filter(([k]) => allowed.includes(k))
    .map(([k]) => `${k} = ?`);
  if (sets.length === 0) return res.json({ ok: true });
  const vals = Object.entries(updates).filter(([k]) => allowed.includes(k)).map(([,v]) => v);
  db.prepare(`UPDATE user_settings SET ${sets.join(', ')} WHERE user_id = ?`).run(...vals, userId);
  res.json({ ok: true });
});

app.post('/api/settings/background', authMiddleware, upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: '未选择文件' });
  try {
    const url = await uploadToR2(req.file.path, req.file.originalname);
    db.prepare('UPDATE user_settings SET chat_background = ? WHERE user_id = ?').run(url, req.userId);
    res.json({ url });
  } catch (e) {
    const url = `/uploads/${req.file.filename}`;
    console.error('File server upload failed for background, local fallback:', e.message);
    db.prepare('UPDATE user_settings SET chat_background = ? WHERE user_id = ?').run(url, req.userId);
    res.json({ url });
  }
});

// ─── WebSocket ─────────────────────────────────────────────────
const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

const wsClients = new Map();

wss.on('connection', (ws, req) => {
  const url = new URL(req.url, 'http://localhost');
  const userId = url.searchParams.get('userId');
  if (!userId) { ws.close(); return; }

  if (!wsClients.has(userId)) wsClients.set(userId, new Set());
  wsClients.get(userId).add(ws);
  console.log(`WS: ${userId} connected (${wss.clients.size} total)`);

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data.toString());
      const { type } = msg;

      // Ping/pong for keepalive
      if (type === 'ping') {
        ws.send(JSON.stringify({ type: 'pong' }));
        return;
      }

      if (type === 'message') {
        const { conversation_id, sender_id, text } = msg;
        // Validate sender_id matches the connected user
        if (sender_id !== userId) return;

        if (!text || !text.trim()) return;

        const id = uuidv4();
        db.prepare('INSERT INTO messages (id, conversation_id, sender_id, text) VALUES (?, ?, ?, ?)')
          .run(id, conversation_id, sender_id, stripHtml(text));

        const fullMsg = db.prepare(`
          SELECT m.*, u.name as sender_name, u.avatar as sender_avatar
          FROM messages m JOIN users u ON u.id = m.sender_id WHERE m.id = ?
        `).get(id);

        const members = db.prepare('SELECT user_id FROM conversation_members WHERE conversation_id = ?')
          .all(conversation_id);
        for (const m of members) {
          const clients = wsClients.get(m.user_id);
          if (clients) clients.forEach(c => { try { c.send(JSON.stringify(fullMsg)); } catch {} });
        }
      }

      // Call Signaling
      if (type === 'call:offer' || type === 'call:answer' || type === 'call:ice' || type === 'call:end') {
        const targetClients = wsClients.get(msg.targetUserId);
        if (targetClients) {
          targetClients.forEach(c => { try { c.send(JSON.stringify({ ...msg, fromUserId: userId })); } catch {} });
        }
      }
      if (type === 'call:busy') {
        const targetClients = wsClients.get(msg.targetUserId);
        if (targetClients) {
          targetClients.forEach(c => { try { c.send(JSON.stringify({ ...msg, fromUserId: userId })); } catch {} });
        }
      }
      if (type === 'typing') {
        const { conversation_id, sender_id } = msg;
        const members = db.prepare('SELECT user_id FROM conversation_members WHERE conversation_id = ?')
          .all(conversation_id);
        for (const m of members) {
          if (m.user_id === sender_id) continue;
          const clients = wsClients.get(m.user_id);
          if (clients) clients.forEach(c => { try { c.send(JSON.stringify({ type: 'typing', conversation_id, sender_id })); } catch {} });
        }
      }
    } catch(e) { console.error('WS error:', e.message); }
  });

  ws.on('close', () => {
    const clients = wsClients.get(userId);
    if (clients) {
      clients.delete(ws);
      if (clients.size === 0) wsClients.delete(userId);
    }
    console.log(`WS: ${userId} disconnected (${wss.clients.size} total)`);
  });

  ws.on('error', () => {
    const clients = wsClients.get(userId);
    if (clients) {
      clients.delete(ws);
      if (clients.size === 0) wsClients.delete(userId);
    }
  });
});

server.listen(PORT, () => {
  console.log(`NeoAnt Server running on port ${PORT}`);
});
