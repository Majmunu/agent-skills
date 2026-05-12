import express from 'express';

const app = express();

app.get('/', (_req, res) => {
  res.json({ message: 'existing-claude-only fixture' });
});

export default app;
