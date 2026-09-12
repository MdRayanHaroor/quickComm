# Deploying QuickComm Backend on Vercel

This guide outlines how to deploy the FastAPI backend as a standalone Serverless application on Vercel and connect it to your Admin Panel.

---

## 1. Prerequisites
- Your repository pushed to GitHub / GitLab / Bitbucket.
- Supabase Project credentials (URL, Anon Key, and Service Role Key).

---

## 2. Deploy via Vercel Dashboard

1. Log in to [Vercel](https://vercel.com).
2. Click **Add New...** > **Project**.
3. Select your **quickComm** repository and click **Import**.
4. In the **Configure Project** screen:
   * **Project Name**: e.g., `quickcomm-backend` (or your preferred name).
   * **Framework Preset**: Select **Other** or let Vercel auto-detect (FastAPI).
   * **Root Directory**: Click **Edit** and choose `backend`.
5. Expand **Environment Variables** and add the following:
   * `SUPABASE_URL`: Your Supabase project URL (e.g. `https://xxxx.supabase.co`)
   * `SUPABASE_KEY`: Your Supabase anon / public key
   * `SUPABASE_SERVICE_KEY`: Your Supabase `service_role` secret key (needed for rider management)
6. Click **Deploy**.

---

## 3. Verify the Deployment

Once deployment completes, Vercel will provide you with a production URL (e.g. `https://quickcomm-backend.vercel.app`).

You can verify the backend is live by opening:
* `https://your-backend-url.vercel.app/health` &rarr; should return `{"status": "ok"}`
* `https://your-backend-url.vercel.app/docs` &rarr; should open the interactive FastAPI Swagger documentation

---

## 4. Connect Admin Panel to the Vercel Backend

Now that your backend is running on Vercel:

1. Open your Admin Panel project on Vercel.
2. Go to **Settings** > **Environment Variables**.
3. Add or update:
   * **Key**: `VITE_API_BASE_URL`
   * **Value**: `https://your-backend-url.vercel.app` (without trailing slash)
4. Redeploy the Admin Panel (or trigger a new build) for the updated environment variable to take effect.
