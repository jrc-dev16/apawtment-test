const express = require('express');
const nodemailer = require('nodemailer');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(bodyParser.json());

app.post('/send-email', async (req, res) => {
  const { to, username, password, first_name, middle_name, last_name, suffix_name } = req.body;

  try {
    // Create transporter
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: 'YOUR_GMAIL@gmail.com', // your Gmail
        pass: 'YOUR_APP_PASSWORD', // Gmail App Password, NOT your regular password
      },
    });

    // Compose message
    const mailOptions = {
      from: 'YOUR_GMAIL@gmail.com',
      to,
      subject: 'Your Subadmin Account Info',
      html: `
        <p>Hi ${first_name} ${middle_name} ${last_name} ${suffix_name},</p>
        <p>Your subadmin account has been created.</p>
        <p>Username: <b>${username}</b></p>
        <p>Password: <b>${password}</b></p>
        <p>Please login to your account.</p>
      `,
    };

    // Send email
    await transporter.sendMail(mailOptions);

    res.status(200).json({ message: 'Email sent successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Failed to send email', error: err.toString() });
  }
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
