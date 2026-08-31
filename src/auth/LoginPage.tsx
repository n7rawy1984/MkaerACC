import { useState, type FormEvent } from "react";
import { useT } from "../i18n/I18nContext";
import { AuthFrame } from "./AuthFrame";
import { useAuth } from "./AuthContext";

export function LoginPage() {
  const t = useT();
  const { signIn } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<"invalid" | "connectivity" | null>(null);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (pending) return;
    setPending(true);
    setError(null);
    const result = await signIn(email.trim(), password);
    if (!result.ok) setError(result.kind);
    setPending(false);
  };

  return (
    <AuthFrame>
      <h1 className="text-2xl font-semibold">{t("auth.loginTitle")}</h1>
      <p className="mt-2 text-sm text-slate-600">{t("auth.loginSubtitle")}</p>
      <form className="mt-6 space-y-4" onSubmit={submit}>
        <label className="block text-sm font-medium">{t("auth.email")}
          <input type="email" autoComplete="email" required value={email} onChange={(event) => setEmail(event.target.value)} disabled={pending} className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100" />
        </label>
        <label className="block text-sm font-medium">{t("auth.password")}
          <input type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} disabled={pending} className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100" />
        </label>
        {error && <p className="text-sm text-red-700" role="alert">{t(error === "invalid" ? "auth.invalidCredentials" : "auth.connectivityError")}</p>}
        <button type="submit" disabled={pending} className="w-full rounded-lg bg-blue-700 px-4 py-2.5 font-medium text-white hover:bg-blue-800 disabled:cursor-not-allowed disabled:opacity-60">
          {pending ? t("auth.signingIn") : t("auth.signIn")}
        </button>
      </form>
    </AuthFrame>
  );
}
