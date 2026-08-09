// server.js (ES module version)
import express from 'express';
import nodemailer from 'nodemailer';
import bodyParser from 'body-parser';
import cors from 'cors';

const app = express();
app.use(cors({
  origin: ['http://localhost:63115'], // replace with your Flutter Web URL
  methods: ['POST', 'GET'],
  credentials: true
}));
app.use(bodyParser.json());

app.post('/send-email', async (req, res) => {
  const { to, username, password, first_name, middle_name, last_name, suffix_name } = req.body;

  try {
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: 'YOUR_GMAIL@gmail.com',
        pass: 'YOUR_APP_PASSWORD',
      },
    });

   const mailOptions = {
  from: 'YOUR_GMAIL@gmail.com',
  to, // recipient email from request body
  subject: 'Your Subadmin Account Info',
  html: `
    <div style="font-family: Arial; color: #333;">
      <h2>Welcome, ${first_name}!</h2>
      <p>Your subadmin account has been created:</p>
      <ul>
        <li><b>Username:</b> ${username}</li>
        <li><b>Password:</b> ${password}</li>
      </ul>
      <a href="https://yourapp.com/login" style="background:#4CAF50;color:white;padding:10px 20px;text-decoration:none;border-radius:5px;">Login Now</a>
    </div>
  `,
};


    await transporter.sendMail(mailOptions);

    res.status(200).json({ message: 'Email sent successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Failed to send email', error: error.toString() });
  }
});

const PORT = 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
