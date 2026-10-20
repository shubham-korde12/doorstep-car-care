# DOORSTEP CAR CARE — temporary marketing website

A responsive, static marketing website for the initial DOORSTEP CAR CARE launch.

## Files
- `index.html` — page structure, plan content, booking request form, FAQ, and WhatsApp links.
- `styles.css` — responsive visual styling.
- `script.js` — mobile navigation, plan preselection, current year, and WhatsApp booking-message builder.

## Run locally
Open `index.html` in a modern browser. An internet connection is recommended for the Google Fonts and hosted car photograph.

## Deploy to GitHub Pages
1. The website files live at the repository root on the `develop` branch.
2. In **Settings → Pages**, select **GitHub Actions** as the publishing source. Leave **Custom domain** blank unless you own a domain you want to connect.
3. The workflow in `.github/workflows/deploy.yml` publishes the static files whenever website changes are pushed to `develop`.
4. Check the **Actions** tab for a green deployment run, then open `https://shubham-korde12.github.io/doorstep-car-care/`.

## Booking form behavior
The form validates required fields and opens WhatsApp with a pre-filled booking-request message to **+91 74985 57226**. It does not store submissions on a server, and it does not confirm a booking automatically. The business must reply to confirm availability.

## Before public launch
- Verify that +91 74985 57226 is the intended business WhatsApp number.
- Confirm the exact inclusions and operating rules for the Daily Care plan.
- Add a privacy notice before collecting personal information at scale.
- Replace the sample hosted car photograph with approved brand photography if desired.
- Consider adding a real backend endpoint/CRM if enquiries need durable storage and follow-up tracking.
