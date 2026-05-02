const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const { PrismaClient } = require('@prisma/client');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
require('dotenv').config();

const prisma = new PrismaClient();
const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});
const port = process.env.PORT || 3000;

// Cloudflare R2 Client
const s3Client = new S3Client({
  region: 'auto',
  endpoint: process.env.R2_ENDPOINT,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
  },
});

app.use(cors());
app.use(express.json());


// Health Check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', database: 'connected' });
});

// Register User
app.post('/register', async (req, res) => {
  const { username, email, avatar, bio } = req.body;
  
  if (!username) {
    return res.status(400).json({ error: 'Username is required' });
  }

  try {
    const user = await prisma.user.upsert({
      where: { username },
      update: { email, avatar, bio },
      create: { username, email, avatar, bio },
    });
    res.json(user);
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Failed to register user' });
  }
});

// Get User by Username
app.get('/users/:username', async (req, res) => {
  const { username } = req.params;
  try {
    const user = await prisma.user.findUnique({
      where: { username },
      include: {
        moments: {
          where: {
            expiresAt: {
              gt: new Date()
            }
          },
          orderBy: {
            timestamp: 'desc'
          }
        }
      }
    });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Generate Presigned URL for R2 Upload
app.get('/generate-upload-url', async (req, res) => {
  const { fileName, contentType } = req.query;

  if (!fileName || !contentType) {
    return res.status(400).json({ error: 'fileName and contentType are required' });
  }

  const key = `moments/${Date.now()}-${fileName}`;
  const command = new PutObjectCommand({
    Bucket: process.env.R2_BUCKET_NAME,
    Key: key,
    ContentType: contentType,
  });

  try {
    const signedUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
    const publicUrl = `${process.env.R2_PUBLIC_URL}/${key}`;
    res.json({ signedUrl, publicUrl, key });
  } catch (error) {
    console.error('Error generating signed URL:', error);
    res.status(500).json({ error: 'Failed to generate upload URL' });
  }
});

// Create a Moment
app.post('/moments', async (req, res) => {
  const { userId, mediaUrl, caption } = req.body;

  if (!userId || !mediaUrl) {
    return res.status(400).json({ error: 'userId and mediaUrl are required' });
  }

  try {
    const moment = await prisma.moment.create({
      data: {
        userId,
        mediaUrl,
        caption,
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // Expires in 24 hours
      },
    });
    res.json(moment);
  } catch (error) {
    console.error('Error creating moment:', error);
    res.status(500).json({ error: 'Failed to create moment' });
  }
});

// Search Users
app.get('/users/search', async (req, res) => {
  const { q } = req.query;
  if (!q) {
    return res.json([]);
  }

  try {
    const users = await prisma.user.findMany({
      where: {
        username: {
          contains: q,
          mode: 'insensitive',
        },
      },
      take: 20,
      select: {
        id: true,
        username: true,
        avatar: true,
        bio: true,
      }
    });
    res.json(users);
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Failed to search users' });
  }
});

// Add Contact
app.post('/contacts', async (req, res) => {
  const { userId, contactId } = req.body;
  if (!userId || !contactId) {
    return res.status(400).json({ error: 'userId and contactId are required' });
  }

  if (userId === contactId) {
    return res.status(400).json({ error: 'Cannot add yourself as a contact' });
  }

  try {
    const contact = await prisma.contact.create({
      data: {
        userId,
        contactId,
      },
      include: {
        contact: true,
      }
    });
    res.json(contact);
  } catch (error) {
    console.error('Add contact error:', error);
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'Contact already exists' });
    }
    res.status(500).json({ error: 'Failed to add contact' });
  }
});

// Get User's Contacts
app.get('/contacts/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const contacts = await prisma.contact.findMany({
      where: { userId },
      include: {
        contact: {
          select: {
            id: true,
            username: true,
            avatar: true,
            bio: true,
          }
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });
    res.json(contacts);
  } catch (error) {
    console.error('Get contacts error:', error);
    res.status(500).json({ error: 'Failed to fetch contacts' });
  }
});


// Get Recent Chats
app.get('/chats/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    // Buscar mensagens onde o usuário é remetente ou destinatário
    const messages = await prisma.message.findMany({
      where: {
        OR: [
          { senderId: userId },
          { receiverId: userId },
        ],
      },
      orderBy: { timestamp: 'desc' },
      include: {
        // Unfortunately Prisma doesn't support sophisticated distinct logic on relation inclusions out of the box in a single query like this easily for Chat Previews, 
        // so we fetch recent messages and process them in memory.
      }
    });

    // Agrupar por contato
    const chatsMap = new Map();
    
    for (const msg of messages) {
      const contactId = msg.senderId === userId ? msg.receiverId : msg.senderId;
      if (!chatsMap.has(contactId)) {
        chatsMap.set(contactId, {
          contactId: contactId,
          lastMessage: msg.content,
          timestamp: msg.timestamp,
          unreadCount: msg.receiverId === userId && !msg.isRead ? 1 : 0
        });
      } else {
        if (msg.receiverId === userId && !msg.isRead) {
          chatsMap.get(contactId).unreadCount += 1;
        }
      }
    }

    const chatsArray = Array.from(chatsMap.values());

    // Obter dados dos contatos
    const contactIds = chatsArray.map(c => c.contactId);
    const users = await prisma.user.findMany({
      where: { id: { in: contactIds } },
      select: { id: true, username: true, avatar: true }
    });

    const userMap = new Map(users.map(u => [u.id, u]));

    const result = chatsArray.map(c => ({
      contact: userMap.get(c.contactId),
      lastMessage: c.lastMessage,
      timestamp: c.timestamp,
      unreadCount: c.unreadCount
    })).filter(c => c.contact != null);

    res.json(result);
  } catch (error) {
    console.error('Get chats error:', error);
    res.status(500).json({ error: 'Failed to fetch chats' });
  }
});

// Get Moments Feed (Friends' active moments)
app.get('/moments/feed/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    // Buscar contatos
    const contacts = await prisma.contact.findMany({
      where: { userId },
      select: { contactId: true }
    });
    
    const contactIds = contacts.map(c => c.contactId);
    contactIds.push(userId); // Incluir o próprio usuário para ver seus moments

    // Buscar moments desses contatos que não expiraram
    const moments = await prisma.moment.findMany({
      where: {
        userId: { in: contactIds },
        expiresAt: { gt: new Date() }
      },
      include: {
        user: { select: { id: true, username: true, avatar: true } }
      },
      orderBy: { timestamp: 'desc' }
    });

    // Agrupar moments por usuário
    const feedMap = new Map();
    for (const moment of moments) {
      if (!feedMap.has(moment.userId)) {
        feedMap.set(moment.userId, {
          user: moment.user,
          latestTimestamp: moment.timestamp,
          moments: []
        });
      }
      feedMap.get(moment.userId).moments.push(moment);
    }

    res.json(Array.from(feedMap.values()));
  } catch (error) {
    console.error('Get moments feed error:', error);
    res.status(500).json({ error: 'Failed to fetch moments feed' });
  }
});

// Get Messages History
app.get('/messages/:userId1/:userId2', async (req, res) => {
  const { userId1, userId2 } = req.params;
  try {
    const messages = await prisma.message.findMany({
      where: {
        OR: [
          { senderId: userId1, receiverId: userId2 },
          { senderId: userId2, receiverId: userId1 },
        ],
      },
      orderBy: {
        timestamp: 'asc',
      },
    });
    res.json(messages);
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

// Socket.IO Logic
io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  // Join a specific chat room
  socket.on('join_room', (data) => {
    // Room ID is created consistently regardless of who joins first
    const room = [data.userId1, data.userId2].sort().join('_');
    socket.join(room);
    console.log(`Socket ${socket.id} joined room ${room}`);
  });

  // Handle incoming messages
  socket.on('send_message', async (data) => {
    const { senderId, receiverId, content } = data;
    const room = [senderId, receiverId].sort().join('_');

    try {
      // 1. Save to database
      const message = await prisma.message.create({
        data: {
          senderId,
          receiverId,
          content,
        },
      });

      // 2. Broadcast to room
      io.to(room).emit('receive_message', message);
    } catch (error) {
      console.error('Socket send_message error:', error);
    }
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

server.listen(port, () => {
  console.log(`Arroba API running at http://localhost:${port}`);
});
