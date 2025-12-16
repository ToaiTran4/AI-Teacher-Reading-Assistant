const express = require('express');
const cors = require('cors');
const { MongoClient, ObjectId } = require('mongodb');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors()); // Cho phép Flutter Web gọi API
app.use(express.json());

// MongoDB connection (KHÔNG AUTH)
const MONGO_URI = 'mongodb://localhost:27017/Teachain';
let db;

MongoClient.connect(MONGO_URI)
  .then(client => {
    db = client.db('Teachain');
    console.log('✅ MongoDB đã kết nối!');
    
    // Tạo unique index cho email
    db.collection('users').createIndex({ email: 1 }, { unique: true })
      .then(() => console.log('✅ Index email đã tạo'))
      .catch(() => console.log('ℹ️ Index email đã tồn tại'));
  })
  .catch(err => {
    console.error('❌ Lỗi MongoDB:', err);
    process.exit(1);
  });

// ============= AUTH ENDPOINTS =============

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'Backend API đang chạy',
    timestamp: new Date().toISOString()
  });
});

// Đăng ký
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, displayName } = req.body;
    
    if (!email || !password || !displayName) {
      return res.status(400).json({ message: 'Thiếu thông tin bắt buộc' });
    }
    
    // Kiểm tra email đã tồn tại
    const existing = await db.collection('users').findOne({ 
      email: email.toLowerCase() 
    });
    
    if (existing) {
      return res.status(400).json({ message: 'Email đã được sử dụng' });
    }

    // Tạo user mới
    const user = {
      uid: uuidv4(),
      email: email.toLowerCase(),
      password: password, // TODO: Hash password trong production
      displayName: displayName,
      createdAt: new Date().toISOString(),
    };

    await db.collection('users').insertOne(user);
    
    console.log('✅ Đăng ký thành công:', email);
    
    // Xóa password trước khi trả về
    const { password: _, ...userWithoutPassword } = user;

    res.status(201).json({ 
      message: 'Đăng ký thành công',
      user: userWithoutPassword
    });
    
  } catch (error) {
    console.error('❌ Lỗi đăng ký:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// Đăng nhập
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    if (!email || !password) {
      return res.status(400).json({ message: 'Thiếu email hoặc password' });
    }
    
    const user = await db.collection('users').findOne({ 
      email: email.toLowerCase(),
      password: password 
    });
    
    if (!user) {
      return res.status(401).json({ 
        message: 'Email hoặc mật khẩu không đúng' 
      });
    }

    console.log('✅ Đăng nhập thành công:', email);
    
    // Xóa password trước khi trả về
    const { password: _, ...userWithoutPassword } = user;

    res.json({ 
      message: 'Đăng nhập thành công',
      user: userWithoutPassword
    });
    
  } catch (error) {
    console.error('❌ Lỗi đăng nhập:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// Lấy thông tin user
app.get('/api/users/:uid', async (req, res) => {
  try {
    const user = await db.collection('users').findOne({ 
      uid: req.params.uid 
    });
    
    if (!user) {
      return res.status(404).json({ message: 'User không tồn tại' });
    }

    const { password: _, ...userWithoutPassword } = user;
    res.json(userWithoutPassword);
    
  } catch (error) {
    console.error('❌ Lỗi lấy user:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// Đổi mật khẩu
app.post('/api/users/:uid/change-password', async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    
    if (!oldPassword || !newPassword) {
      return res.status(400).json({ message: 'Thiếu thông tin' });
    }
    
    const user = await db.collection('users').findOne({ 
      uid: req.params.uid,
      password: oldPassword 
    });
    
    if (!user) {
      return res.status(401).json({ message: 'Mật khẩu cũ không đúng' });
    }

    await db.collection('users').updateOne(
      { uid: req.params.uid },
      { $set: { password: newPassword } }
    );

    console.log('✅ Đổi mật khẩu thành công:', user.email);
    res.json({ message: 'Đổi mật khẩu thành công' });
    
  } catch (error) {
    console.error('❌ Lỗi đổi mật khẩu:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// Cập nhật profile
app.patch('/api/users/:uid', async (req, res) => {
  try {
    const { displayName } = req.body;
    
    if (!displayName) {
      return res.status(400).json({ message: 'Thiếu displayName' });
    }
    
    await db.collection('users').updateOne(
      { uid: req.params.uid },
      { $set: { displayName } }
    );

    const user = await db.collection('users').findOne({ 
      uid: req.params.uid 
    });
    
    if (!user) {
      return res.status(404).json({ message: 'User không tồn tại' });
    }
    
    const { password: _, ...userWithoutPassword } = user;
    
    console.log('✅ Cập nhật profile thành công:', user.email);
    res.json(userWithoutPassword);
    
  } catch (error) {
    console.error('❌ Lỗi cập nhật profile:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// ============= DOCUMENTS ENDPOINTS (GridFS) =============

// Upload document với GridFS
app.post('/api/documents/upload', async (req, res) => {
  try {
    const { docId, userId, fileName, fileData, fileSize } = req.body;
    
    if (!docId || !userId || !fileName || !fileData) {
      return res.status(400).json({ message: 'Thiếu thông tin' });
    }
    
    // Decode base64 về bytes
    const bytes = Buffer.from(fileData, 'base64');
    
    // Lưu vào GridFS (fs.files collection)
    const fileDoc = {
      _id: docId,
      filename: fileName,
      userId: userId,
      data: bytes,
      length: bytes.length,
      uploadedAt: new Date().toISOString(),
      contentType: 'application/pdf',
    };
    
    await db.collection('fs.files').insertOne(fileDoc);
    
    // Lưu metadata vào documents collection
    const document = {
      id: docId,
      userId: userId,
      fileName: fileName,
      storageUrl: `mongo://fs.files/${docId}`,
      fileSize: fileSize,
      uploadedAt: new Date().toISOString(),
      isProcessed: false,
    };
    
    await db.collection('documents').insertOne(document);
    
    console.log('✅ Upload file thành công:', fileName);
    res.status(201).json({ 
      message: 'Upload thành công',
      document 
    });
    
  } catch (error) {
    console.error('❌ Lỗi upload document:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// Get user documents
app.get('/api/documents/user/:userId', async (req, res) => {
  try {
    const docs = await db.collection('documents')
      .find({ userId: req.params.userId })
      .sort({ uploadedAt: -1 })
      .toArray();
    res.json(docs);
  } catch (error) {
    console.error('❌ Lỗi lấy documents:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// Update document processed status
app.patch('/api/documents/:docId', async (req, res) => {
  try {
    const { isProcessed, qdrantCollectionId, vectorCount } = req.body;
    await db.collection('documents').updateOne(
      { id: req.params.docId },
      { $set: { isProcessed, qdrantCollectionId, vectorCount } }
    );
    res.json({ message: 'Document updated' });
  } catch (error) {
    console.error('❌ Lỗi cập nhật document:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// Delete document
app.delete('/api/documents/:docId', async (req, res) => {
  try {
    const docId = req.params.docId;
    
    // Xóa file từ GridFS
    await db.collection('fs.files').deleteOne({ _id: docId });
    
    // Xóa metadata
    await db.collection('documents').deleteOne({ id: docId });
    
    console.log('✅ Xóa document thành công:', docId);
    res.json({ message: 'Document deleted' });
  } catch (error) {
    console.error('❌ Lỗi xóa document:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// Download document bytes
app.get('/api/documents/:docId/download', async (req, res) => {
  try {
    const docId = req.params.docId;
    
    // Lấy file từ GridFS
    const fileDoc = await db.collection('fs.files').findOne({ _id: docId });
    
    if (!fileDoc) {
      return res.status(404).json({ message: 'File không tồn tại' });
    }
    
    // Trả về base64
    const base64Data = fileDoc.data.toString('base64');
    
    res.json({ 
      fileName: fileDoc.filename,
      fileData: base64Data,
      fileSize: fileDoc.length,
    });
    
  } catch (error) {
    console.error('❌ Lỗi download document:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});
// Thêm vào server.js sau các endpoints hiện tại

// ============= CHUNKED UPLOAD =============

// Lưu tạm các chunks đang upload
const uploadSessions = new Map();

// Bắt đầu upload session
app.post('/api/documents/upload/start', async (req, res) => {
  try {
    const { docId, userId, fileName, fileSize, totalChunks } = req.body;
    
    console.log(`🚀 Bắt đầu upload: ${fileName} (${fileSize} bytes, ${totalChunks} chunks)`);
    
    // Tạo session
    uploadSessions.set(docId, {
      userId,
      fileName,
      fileSize,
      totalChunks,
      receivedChunks: new Map(),
      startTime: Date.now(),
    });
    
    res.json({ 
      message: 'Upload session created',
      docId 
    });
    
  } catch (error) {
    console.error('❌ Lỗi start upload:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// Upload từng chunk
app.post('/api/documents/upload/chunk', async (req, res) => {
  try {
    const { docId, chunkIndex, chunkData } = req.body;
    
    const session = uploadSessions.get(docId);
    if (!session) {
      return res.status(404).json({ message: 'Session không tồn tại' });
    }
    
    // Lưu chunk
    session.receivedChunks.set(chunkIndex, Buffer.from(chunkData, 'base64'));
    
    const progress = (session.receivedChunks.size / session.totalChunks * 100).toFixed(1);
    console.log(`📦 Chunk ${chunkIndex}/${session.totalChunks - 1} - ${progress}%`);
    
    res.json({ 
      message: 'Chunk received',
      received: session.receivedChunks.size,
      total: session.totalChunks,
      progress: parseFloat(progress)
    });
    
  } catch (error) {
    console.error('❌ Lỗi upload chunk:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// Hoàn thành upload
app.post('/api/documents/upload/complete', async (req, res) => {
  try {
    const { docId } = req.body;
    
    const session = uploadSessions.get(docId);
    if (!session) {
      return res.status(404).json({ message: 'Session không tồn tại' });
    }
    
    // Kiểm tra đã nhận đủ chunks chưa
    if (session.receivedChunks.size !== session.totalChunks) {
      return res.status(400).json({ 
        message: 'Chưa nhận đủ chunks',
        received: session.receivedChunks.size,
        expected: session.totalChunks
      });
    }
    
    console.log('🔄 Ghép các chunks lại...');
    
    // Ghép tất cả chunks theo thứ tự
    const chunks = [];
    for (let i = 0; i < session.totalChunks; i++) {
      const chunk = session.receivedChunks.get(i);
      if (!chunk) {
        throw new Error(`Missing chunk ${i}`);
      }
      chunks.push(chunk);
    }
    
    const completeFile = Buffer.concat(chunks);
    console.log(`✅ File ghép xong: ${completeFile.length} bytes`);
    
    // Lưu vào GridFS
    const fileDoc = {
      _id: docId,
      filename: session.fileName,
      userId: session.userId,
      data: completeFile,
      length: completeFile.length,
      uploadedAt: new Date().toISOString(),
      contentType: 'application/pdf',
    };
    
    await db.collection('fs.files').insertOne(fileDoc);
    
    // Lưu metadata
    const document = {
      id: docId,
      userId: session.userId,
      fileName: session.fileName,
      storageUrl: `mongo://fs.files/${docId}`,
      fileSize: session.fileSize,
      uploadedAt: new Date().toISOString(),
      isProcessed: false,
    };
    
    await db.collection('documents').insertOne(document);
    
    // Xóa session
    uploadSessions.delete(docId);
    
    const uploadTime = ((Date.now() - session.startTime) / 1000).toFixed(1);
    console.log(`✅ Upload hoàn tất: ${session.fileName} trong ${uploadTime}s`);
    
    res.json({ 
      message: 'Upload thành công',
      document,
      uploadTimeSeconds: parseFloat(uploadTime)
    });
    
  } catch (error) {
    console.error('❌ Lỗi complete upload:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// Hủy upload
app.post('/api/documents/upload/cancel', async (req, res) => {
  try {
    const { docId } = req.body;
    
    if (uploadSessions.has(docId)) {
      uploadSessions.delete(docId);
      console.log(`🗑️ Hủy upload: ${docId}`);
      res.json({ message: 'Upload cancelled' });
    } else {
      res.status(404).json({ message: 'Session không tồn tại' });
    }
    
  } catch (error) {
    console.error('❌ Lỗi cancel upload:', error);
    res.status(500).json({ message: 'Lỗi server: ' + error.message });
  }
});

// Dọn dẹp sessions cũ (>1 giờ không hoàn thành)
setInterval(() => {
  const now = Date.now();
  const oneHour = 60 * 60 * 1000;
  
  for (const [docId, session] of uploadSessions.entries()) {
    if (now - session.startTime > oneHour) {
      uploadSessions.delete(docId);
      console.log(`🗑️ Dọn dẹp session cũ: ${docId}`);
    }
  }
}, 10 * 60 * 1000); // Check mỗi 10 phút
// Start server
app.listen(PORT, () => {
  console.log('');
  console.log('🚀 ===================================');
  console.log(`   Server đang chạy tại:`);
  console.log(`   http://localhost:${PORT}`);
  console.log('🚀 ===================================');
  console.log(`📡 API endpoints:`);
  console.log(`   Health: http://localhost:${PORT}/api/health`);
  console.log(`   Auth:   http://localhost:${PORT}/api/auth/*`);
  console.log(`   Users:  http://localhost:${PORT}/api/users/*`);
  console.log(`   Docs:   http://localhost:${PORT}/api/documents/*`);
  console.log('');
});