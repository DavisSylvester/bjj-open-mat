/**
 * Promotes a given versionCode from the internal draft track to production
 * and commits the edit (sends for review).
 *
 * Usage: node scripts/play-promote-to-production.mjs <versionCode>
 * Example: node scripts/play-promote-to-production.mjs 112
 */
import { google } from 'googleapis';

const PACKAGE = 'com.davissylvester.bjjopenmat';
const SA_PATH = './.google-service-account.json';

const VERSION_CODE = parseInt(process.argv[2] ?? '', 10);
if (!VERSION_CODE) {
  console.error('Usage: node play-promote-to-production.mjs <versionCode>');
  process.exit(1);
}

const auth = new google.auth.GoogleAuth({
  keyFile: SA_PATH,
  scopes: ['https://www.googleapis.com/auth/androidpublisher'],
});

const publisher = google.androidpublisher({ version: 'v3', auth });

async function main() {
  const editRes = await publisher.edits.insert({ packageName: PACKAGE });
  const editId = editRes.data.id;
  console.log('Opened edit:', editId);

  // Verify the versionCode is on the internal track
  const internalRes = await publisher.edits.tracks.get({
    packageName: PACKAGE,
    editId,
    track: 'internal',
  });
  const allCodes = (internalRes.data.releases ?? []).flatMap(r => r.versionCodes ?? []);
  console.log('Internal versionCodes available:', allCodes);
  if (!allCodes.map(String).includes(String(VERSION_CODE))) {
    console.error(`versionCode ${VERSION_CODE} is not on the internal track. Available: ${allCodes}`);
    await publisher.edits.delete({ packageName: PACKAGE, editId });
    process.exit(1);
  }

  const releaseNotes = [
    {
      language: 'en-US',
      text: 'Fixed open-mat discovery so nearby sessions load reliably, cleaned up the profile screen, and removed all placeholder data. The app now shows only real, community-submitted open mats.',
    },
  ];

  await publisher.edits.tracks.update({
    packageName: PACKAGE,
    editId,
    track: 'production',
    requestBody: {
      track: 'production',
      releases: [
        {
          name: `0.1.0 (${VERSION_CODE}) – policy fixes`,
          versionCodes: [String(VERSION_CODE)],
          status: 'completed',
          releaseNotes,
        },
      ],
    },
  });
  console.log(`Production track updated with versionCode ${VERSION_CODE}.`);

  const commitRes = await publisher.edits.commit({ packageName: PACKAGE, editId });
  console.log('Edit committed — release sent for Google review.');
  console.log('Edit expiry:', commitRes.data.expiryTimeSeconds);
}

main().catch(err => {
  console.error('FAILED:', err.message ?? err);
  process.exit(1);
});
