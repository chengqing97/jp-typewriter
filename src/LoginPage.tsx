import styles from "./LoginPage.module.css";
import { useState } from "react";
import {
  AppwriteException,
  ID,
  useAppwrite,
  useAuth,
} from "@appwrite.io/react";

export default function LoginPage() {
  const { account } = useAppwrite();
  const { error, refresh } = useAuth();
  const [email, setEmail] = useState("");
  const [secret, setSecret] = useState("");
  const [userId, setUserId] = useState("");
  const [message, setMessage] = useState("");
  const [sending, setSending] = useState(false);
  const [loggingIn, setLoggingIn] = useState(false);

  async function sendOTP() {
    setSending(true);
    try {
      const token = await account.createEmailToken({
        userId: ID.unique(),
        email,
      });
      setMessage("Sent!");
      setUserId(token.userId);
    } catch (e) {
      if (e instanceof AppwriteException) {
        setMessage(e.message);
      } else {
        setMessage("Failed to send OTP.");
      }
      console.error(e);
    } finally {
      setSending(false);
    }
  }

  async function login() {
    setLoggingIn(true);
    try {
      await account.createSession({ userId, secret });
      refresh();
    } catch (e) {
      if (e instanceof AppwriteException) {
        setMessage(e.message);
      } else {
        setMessage("Failed to login.");
      }
      console.error(e);
    } finally {
      setLoggingIn(false);
    }
  }

  return (
    <div className={styles.layout}>
      <h1>Login</h1>
      <input
        placeholder="Email"
        type="email"
        value={email}
        onChange={(e) => {
          setMessage("");
          setEmail(e.target.value);
        }}
      />
      <input
        placeholder="OTP"
        value={secret}
        onChange={(e) => {
          setMessage("");
          setSecret(e.target.value);
        }}
      />
      <div className={styles.row}>
        <button onClick={sendOTP} disabled={!email || sending}>
          Send OTP
        </button>
        <button
          onClick={login}
          disabled={secret.length < 6 || !email || !userId || loggingIn}
        >
          Login
        </button>
      </div>
      <p>{message}</p>
      {error && <p style={{ color: "red" }}>{error.message}</p>}
    </div>
  );
}
